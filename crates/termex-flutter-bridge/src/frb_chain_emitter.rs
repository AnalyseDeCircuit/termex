//! Per-session ChainProgress queue (v0.68.0 G3).
//!
//! Mirrors the SSH / SFTP emitter pattern — the chain orchestrator pushes
//! events into a `VecDeque` keyed by session id; Dart drains them on its
//! polling cadence. Polling beats StreamSink here because the existing
//! provider plumbing already wires `pollSshEvents`-style 16ms timers.

use std::collections::VecDeque;
use std::sync::Mutex;

use dashmap::DashMap;
use once_cell::sync::Lazy;
use termex_core::ssh::chain::ChainProgress;

/// Per-session-id event queue. Flutter drains via [`drain`] and unregisters
/// when the chain terminates (success or failure).
static QUEUES: Lazy<DashMap<String, Mutex<VecDeque<ChainProgressDto>>>> = Lazy::new(DashMap::new);

/// Dart-facing flat shape. ChainProgress is an enum-with-payload, which
/// FRB can express but the Riverpod provider treats more cleanly as a
/// single struct with a `kind` discriminator.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChainProgressDto {
    /// One of `"connecting"` / `"hopConnected"` / `"hopFailed"` /
    /// `"chainFailed"` / `"chainConnected"`.
    pub kind: String,
    pub hop_index: i32,
    pub hop_total: i32,
    pub hop_name: String,
    pub attempt: i32,
    pub elapsed_ms: i64,
    pub next_attempt_in_ms: i64,
    pub will_retry: bool,
    pub error: Option<String>,
}

impl ChainProgressDto {
    pub fn from_progress(event: ChainProgress) -> Self {
        match event {
            ChainProgress::Connecting { hop_index, hop_total, hop_name, attempt } => Self {
                kind: "connecting".into(),
                hop_index: hop_index as i32,
                hop_total: hop_total as i32,
                hop_name,
                attempt: attempt as i32,
                elapsed_ms: 0,
                next_attempt_in_ms: 0,
                will_retry: false,
                error: None,
            },
            ChainProgress::HopConnected { hop_index, hop_total, hop_name, elapsed_ms } => Self {
                kind: "hopConnected".into(),
                hop_index: hop_index as i32,
                hop_total: hop_total as i32,
                hop_name,
                attempt: 0,
                elapsed_ms: elapsed_ms as i64,
                next_attempt_in_ms: 0,
                will_retry: false,
                error: None,
            },
            ChainProgress::HopFailed {
                hop_index,
                hop_name,
                attempt,
                error,
                will_retry,
                next_attempt_in_ms,
            } => Self {
                kind: "hopFailed".into(),
                hop_index: hop_index as i32,
                hop_total: 0,
                hop_name,
                attempt: attempt as i32,
                elapsed_ms: 0,
                next_attempt_in_ms: next_attempt_in_ms as i64,
                will_retry,
                error: Some(error),
            },
            ChainProgress::ChainFailed { failed_at_hop, hop_name, error } => Self {
                kind: "chainFailed".into(),
                hop_index: failed_at_hop as i32,
                hop_total: 0,
                hop_name,
                attempt: 0,
                elapsed_ms: 0,
                next_attempt_in_ms: 0,
                will_retry: false,
                error: Some(error),
            },
            ChainProgress::ChainConnected { total_elapsed_ms } => Self {
                kind: "chainConnected".into(),
                hop_index: 0,
                hop_total: 0,
                hop_name: String::new(),
                attempt: 0,
                elapsed_ms: total_elapsed_ms as i64,
                next_attempt_in_ms: 0,
                will_retry: false,
                error: None,
            },
        }
    }
}

pub fn register(session_id: String) {
    QUEUES.insert(session_id, Mutex::new(VecDeque::new()));
}

pub fn unregister(session_id: &str) {
    QUEUES.remove(session_id);
}

pub fn enqueue(session_id: &str, dto: ChainProgressDto) {
    if let Some(entry) = QUEUES.get(session_id) {
        if let Ok(mut q) = entry.lock() {
            q.push_back(dto);
        }
    }
}

pub fn drain(session_id: &str) -> Vec<ChainProgressDto> {
    let Some(entry) = QUEUES.get(session_id) else {
        return Vec::new();
    };
    let Ok(mut q) = entry.lock() else {
        return Vec::new();
    };
    q.drain(..).collect()
}
