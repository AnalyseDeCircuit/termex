//! Resolve an [`EgressProfile`] into a runnable
//! [`crate::ssh::chain::ChainConnectConfig`].
//!
//! The profile stores `HopRef { hop_id, hop_type, position }`
//! where `hop_id` is a row id in the `servers` table. This module
//! does the lookup + ordering so the SSH connect path can ask "what
//! chain should I build for server X?" without knowing anything
//! about how the profile was stored.
//!
//! Returns `Ok(None)` for the legitimate fallback cases (no
//! profile bound, profile deleted, profile has zero hops). The
//! caller is expected to fall through to a direct connect when
//! `None` is returned — see v0.74.0 acceptance items 4-5.

use log::warn;
use rusqlite::{params, Connection, OptionalExtension};

use crate::ssh::chain::{ChainConnectConfig, HopConfig};

use super::storage::{self as egress_storage, EgressError};
use super::{EgressProfile, HopRef};

/// Look up the egress profile bound to `server_id`, resolve every
/// hop, and build a `ChainConnectConfig`. The legacy "direct
/// connect" fall-through is the caller's job — we only own the
/// resolution step.
///
/// Returns `Ok(None)` when:
///   - `server_id` has no `egress_profile_id` set, or
///   - the bound `egress_profile_id` no longer references an
///     existing profile (logged at WARN — likely a stale row that
///     survived a profile delete), or
///   - the profile resolves but has zero hops (no SSH chain to
///     build; caller falls back to direct).
pub fn resolve_chain_for_server(
    conn: &Connection,
    server_id: &str,
) -> Result<Option<ChainConnectConfig>, EgressError> {
    let profile_id = lookup_bound_profile_id(conn, server_id)?;
    let profile_id = match profile_id {
        Some(id) => id,
        None => return Ok(None),
    };
    let profile = match egress_storage::get(conn, &profile_id)? {
        Some(p) => p,
        None => {
            warn!(
                "egress: bound profile id no longer exists for server {} (profile_id={}); \
                 falling back to direct connect",
                server_id, profile_id
            );
            return Ok(None);
        }
    };
    resolve_profile(conn, &profile)
}

/// Resolve an already-loaded profile into a chain config. Pure
/// SQL lookups; no side effects beyond the warn log when a hop_id
/// is missing.
pub fn resolve_profile(
    conn: &Connection,
    profile: &EgressProfile,
) -> Result<Option<ChainConnectConfig>, EgressError> {
    if profile.chain_hops.is_empty() {
        return Ok(None);
    }
    let mut hops = profile.chain_hops.clone();
    hops.sort_by_key(|h| h.position);

    let mut resolved = Vec::with_capacity(hops.len());
    for hop in hops {
        match resolve_hop(conn, &hop)? {
            Some(cfg) => resolved.push(cfg),
            None => {
                warn!(
                    "egress: hop_id {} (type={}) not found in servers table for profile {}; \
                     chain assembly aborted",
                    hop.hop_id, hop.hop_type, profile.id
                );
                return Ok(None);
            }
        }
    }
    Ok(Some(ChainConnectConfig::new(resolved)))
}

/// Look up `server.egress_profile_id` for the given server id.
/// Returns `Ok(None)` when the column is absent (older client DBs
/// haven't run migration #28 yet) or when the row's column is NULL.
fn lookup_bound_profile_id(
    conn: &Connection,
    server_id: &str,
) -> Result<Option<String>, EgressError> {
    let has_column = conn
        .query_row(
            "SELECT 1 FROM pragma_table_info('servers') WHERE name = 'egress_profile_id'",
            [],
            |_| Ok(()),
        )
        .optional()?
        .is_some();
    if !has_column {
        return Ok(None);
    }
    let row: Option<Option<String>> = conn
        .query_row(
            "SELECT egress_profile_id FROM servers WHERE id = ?1",
            params![server_id],
            |r| r.get::<_, Option<String>>(0),
        )
        .optional()?;
    Ok(row.flatten())
}

/// Resolve a single [`HopRef`] by looking up the underlying server
/// row. Currently only `hop_type == "ssh"` is supported — future
/// hop kinds (proxy, jump-host pool) would add their own arms.
fn resolve_hop(conn: &Connection, hop: &HopRef) -> Result<Option<HopConfig>, EgressError> {
    if hop.hop_type != "ssh" {
        warn!(
            "egress: unsupported hop_type '{}'; returning None aborts chain",
            hop.hop_type
        );
        return Ok(None);
    }
    let hop_id_owned = hop.hop_id.clone();
    let row: Option<(String, String, i64)> = conn
        .query_row(
            "SELECT name, host, port FROM servers WHERE id = ?1",
            params![hop.hop_id],
            |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
        )
        .optional()?;
    Ok(row.map(|(name, host, port)| HopConfig {
        hop_id: hop_id_owned,
        name,
        host,
        port: port as u16,
    }))
}
