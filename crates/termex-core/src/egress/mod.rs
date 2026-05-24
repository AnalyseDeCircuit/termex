//! `EgressProfile` — a reusable named "network identity" so the
//! same SSH chain hops + proxy can be bound to multiple servers
//! and synced across devices.
//!
//! Pure DTO + storage layer (v0.74.0 scope). Cross-device sync
//! merger logic lives in `termex-core-private::sync` (v0.74.0+).
//! Runtime ChainConnectConfig wiring lands when ssh::chain learns
//! about `server.egress_profile_id`.
//!
//! See `docs/iterations/v0.74.0-mobile-egress-profile-and-sync.md`.

pub mod resolver;
pub mod storage;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct EgressProfile {
    /// uuid v4
    pub id: String,

    /// Human-readable label ("Office Bastion", "Home VPN"). Unique
    /// per owner_device — the merger uses (name, owner_device) as
    /// the conflict-detection key.
    pub name: String,

    /// SSH jump host chain — serialized as JSON in storage so we
    /// can evolve `HopConfig` without breaking sync.
    pub chain_hops: Vec<HopRef>,

    /// FK to `proxies.id` for an optional outbound proxy. None when
    /// the chain itself is the only egress shaping.
    pub proxy_id: Option<String>,

    /// device_id of the device that originally created the profile.
    /// Used by sync to break ties: when both devices have edited the
    /// same id, owner_device wins; otherwise updated_at wins.
    pub owner_device: Option<String>,

    pub created_at: String, // RFC3339
    pub updated_at: String, // RFC3339
}

/// Lightweight hop reference. The actual SSH chain engine lives in
/// `termex-core::ssh::chain`; this struct is the bit that survives a
/// sync roundtrip without coupling the wire schema to whichever
/// fields the chain engine eventually grows.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HopRef {
    /// Position in the chain, 0-indexed.
    pub position: u32,

    /// One of "ssh" / "proxy".
    pub hop_type: String,

    /// uuid pointing at the underlying server (when hop_type=ssh)
    /// or proxy (when hop_type=proxy).
    pub hop_id: String,
}

impl EgressProfile {
    pub fn new(name: String, owner_device: Option<String>) -> Self {
        let now = chrono::Utc::now().to_rfc3339();
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            name,
            chain_hops: Vec::new(),
            proxy_id: None,
            owner_device,
            created_at: now.clone(),
            updated_at: now,
        }
    }

    /// Mark updated_at = now. Callers should invoke this before
    /// persisting any mutation.
    pub fn touch(&mut self) {
        self.updated_at = chrono::Utc::now().to_rfc3339();
    }

    /// Re-stamp chain_hops positions to be 0..n in array order. Use
    /// after a reorder / insert / delete to keep the wire shape
    /// canonical.
    pub fn renumber_hops(&mut self) {
        for (i, h) in self.chain_hops.iter_mut().enumerate() {
            h.position = i as u32;
        }
    }
}

/// Reverse-lookup-friendly summary used by the picker UI: doesn't
/// pull the full hop list, just enough to render a list row.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct EgressProfileSummary {
    pub id: String,
    pub name: String,
    pub hop_count: usize,
    pub has_proxy: bool,
    pub bound_server_count: usize,
}
