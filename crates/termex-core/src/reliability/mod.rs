//! Per-task reliability metrics — how long was the WebSocket up,
//! how many reconnects, how much time spent in background, how
//! responsive was push, how often was the task handed over.
//!
//! v0.75.0 ships the data model + SQLite storage. The Flutter
//! ReliabilityMetricsProvider + dev-mode footer surface these
//! numbers; the Android Foreground Service + iOS BGTaskScheduler
//! feed them via the bridge.

pub mod metrics;
pub mod storage;

use serde::{Deserialize, Serialize};

/// All counters/timers default to zero so a task without any
/// observed lifecycle still produces a renderable row — the UI
/// shows "WS 0s · 0 reconnects · …".
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TaskMetrics {
    pub task_id: String,
    /// Cumulative WebSocket connected time (ms).
    pub ws_uptime_ms: u64,
    /// Number of times the daemon connection had to be re-established.
    pub reconnect_count: u32,
    /// Cumulative time the app was in background while this task
    /// was alive (ms). Helps quantify how much of the run the user
    /// was actually away from.
    pub bg_duration_ms: u64,
    /// Last observed end-to-end push latency for this task (ms).
    /// `None` when no push has been received yet.
    pub push_latency_ms: Option<u32>,
    /// Number of cross-device handoffs that have touched this task.
    pub handoff_count: u32,
    pub updated_at: String, // RFC3339
}

impl TaskMetrics {
    /// Zero-valued snapshot for a newly seen task.
    pub fn empty(task_id: impl Into<String>, now_rfc3339: impl Into<String>) -> Self {
        Self {
            task_id: task_id.into(),
            ws_uptime_ms: 0,
            reconnect_count: 0,
            bg_duration_ms: 0,
            push_latency_ms: None,
            handoff_count: 0,
            updated_at: now_rfc3339.into(),
        }
    }
}

#[derive(Debug, thiserror::Error)]
pub enum ReliabilityError {
    #[error("sql: {0}")]
    Sql(#[from] rusqlite::Error),
}
