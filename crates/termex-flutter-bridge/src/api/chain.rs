//! Connection-chain CRUD bridge API.
//!
//! The chain captures the ordered set of hops (SSH bastions + network
//! proxies) that the SSH session traverses on its way to the target
//! server. v0.79.20 adds the read/write surface required by the mobile
//! ServerFormDialog "SSH 隧道 + 代理" tab.

use termex_core::storage::chain;
use termex_core::storage::models;

/// Snapshot of a single chain hop. The DTO mirrors the storage struct
/// but uses primitive types so it codegen's cleanly through FRB.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChainHopDto {
    pub id: String,
    pub server_id: String,
    pub position: i32,
    /// `"ssh"` for an SSH bastion hop, `"proxy"` for a network proxy hop.
    pub hop_type: String,
    /// References `servers.id` (bastion) or `proxies.id` (proxy).
    pub hop_id: String,
    /// `"pre"` = before target, `"post"` = after target. Mobile v0.79.20
    /// only writes `pre` hops.
    pub phase: String,
    pub created_at: String,
}

/// Input for replacing the chain of a server. Position is implicit from
/// vec order — the storage layer assigns 0, 1, 2, … in sequence.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChainHopInputDto {
    pub hop_type: String,
    pub hop_id: String,
    pub phase: String,
}

fn from_core(h: models::ChainHop) -> ChainHopDto {
    ChainHopDto {
        id: h.id,
        server_id: h.server_id,
        position: h.position,
        hop_type: h.hop_type,
        hop_id: h.hop_id,
        phase: h.phase,
        created_at: h.created_at,
    }
}

/// Lists every hop currently associated with `server_id`, ordered by
/// `position`. Returns an empty vec if no chain has been saved.
pub fn chain_list_for_server(server_id: String) -> Result<Vec<ChainHopDto>, String> {
    crate::db_state::with_db(|db| {
        chain::list(db, &server_id)
            .map(|hops| hops.into_iter().map(from_core).collect())
            .map_err(|e| e.to_string())
    })
}

/// Replaces the entire chain for `server_id` with the supplied hops.
/// Pass an empty vec to clear the chain (equivalent to direct connect).
pub fn chain_save_for_server(
    server_id: String,
    hops: Vec<ChainHopInputDto>,
) -> Result<(), String> {
    let core_hops: Vec<models::ChainHopInput> = hops
        .into_iter()
        .map(|h| models::ChainHopInput {
            hop_type: h.hop_type,
            hop_id: h.hop_id,
            phase: h.phase,
        })
        .collect();
    crate::db_state::with_db(|db| {
        chain::save(db, &server_id, &core_hops).map_err(|e| e.to_string())
    })
}

/// Deletes every hop for `server_id`. Server itself is untouched.
pub fn chain_delete_for_server(server_id: String) -> Result<(), String> {
    crate::db_state::with_db(|db| {
        chain::delete(db, &server_id).map_err(|e| e.to_string())
    })
}
