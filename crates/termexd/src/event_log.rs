//! Hot ring + cold DB store for v0.71.2 stream replay.
//!
//! Every broadcast event is allocated a monotonic `seq` (via
//! [`EventBus::next_seq`]) and persisted here. Clients reconnecting
//! supply the last `seq` they saw — we backfill anything newer.
//!
//! The hot tier is an in-memory `VecDeque<(seq, ServerMessage)>`
//! capped at `hot_capacity`. The cold tier is the daemon DB's
//! `events_log` table; rows older than 7 days are pruned by the
//! nightly retention job (see `start_retention_job`).

use std::collections::VecDeque;
use std::sync::Arc;
use std::time::Duration;

use parking_lot::Mutex as SyncMutex;
use tokio::sync::Mutex as AsyncMutex;
use tracing::{debug, info, warn};

use termex_core::daemon::ServerMessage;

use crate::db::Database;

/// One persisted event row.
#[derive(Debug, Clone)]
pub struct LoggedEvent {
    pub seq: u64,
    pub message: ServerMessage,
}

/// Combined hot-ring + cold-DB event log.
#[derive(Clone)]
pub struct EventLog {
    inner: Arc<EventLogInner>,
}

struct EventLogInner {
    db: Arc<AsyncMutex<Database>>,
    hot: SyncMutex<VecDeque<(u64, ServerMessage)>>,
    hot_capacity: usize,
}

impl EventLog {
    pub fn new(db: Arc<AsyncMutex<Database>>) -> Self {
        Self::with_capacity(db, 512)
    }

    pub fn with_capacity(db: Arc<AsyncMutex<Database>>, hot_capacity: usize) -> Self {
        Self {
            inner: Arc::new(EventLogInner {
                db,
                hot: SyncMutex::new(VecDeque::with_capacity(hot_capacity)),
                hot_capacity,
            }),
        }
    }

    /// Append an event. Persists to DB and pushes to the hot ring.
    /// Failure to persist is logged but doesn't abort — replay
    /// degrades gracefully (the client just gets fewer history
    /// rows back).
    pub async fn push(&self, seq: u64, msg: &ServerMessage) {
        // 1. Hot ring (sync, fast).
        {
            let mut hot = self.inner.hot.lock();
            if hot.len() >= self.inner.hot_capacity {
                hot.pop_front();
            }
            hot.push_back((seq, msg.clone()));
        }
        // 2. Cold DB (async, slower but durable).
        let ty = server_message_type(msg);
        let task_id = task_id_of(msg);
        let ts_ms = ts_ms_of(msg);
        let payload = match serde_json::to_string(msg) {
            Ok(s) => s,
            Err(e) => {
                warn!(error = %e, "event_log: serialize failed; skipping persist");
                return;
            }
        };
        let db = self.inner.db.clone();
        let result = {
            let guard = db.lock().await;
            guard.insert_event(seq, task_id.as_deref(), ty, &payload, ts_ms)
        };
        if let Err(e) = result {
            warn!(error = %e, "event_log: insert failed; replay degraded");
        }
    }

    /// Return events with `seq > last_seq`. Checks the hot ring
    /// first; falls back to the cold DB when the hot tier has
    /// already evicted the requested window.
    pub async fn replay_since(&self, last_seq: u64, limit: usize) -> Vec<LoggedEvent> {
        // 1. Try hot ring under a quick sync lock.
        {
            let hot = self.inner.hot.lock();
            if let Some(&(oldest_seq, _)) = hot.front() {
                if oldest_seq <= last_seq + 1 {
                    let out: Vec<LoggedEvent> = hot
                        .iter()
                        .filter(|(s, _)| *s > last_seq)
                        .take(limit)
                        .map(|(s, m)| LoggedEvent {
                            seq: *s,
                            message: m.clone(),
                        })
                        .collect();
                    debug!(count = out.len(), source = "hot", "replay served");
                    return out;
                }
            }
        }
        // 2. Cold DB fallback.
        let rows = match self
            .inner
            .db
            .lock()
            .await
            .query_events_since(last_seq, limit)
        {
            Ok(r) => r,
            Err(e) => {
                warn!(error = %e, "event_log: cold replay failed");
                return Vec::new();
            }
        };
        let mut out = Vec::with_capacity(rows.len());
        for (seq, payload) in rows {
            match serde_json::from_str::<ServerMessage>(&payload) {
                Ok(m) => out.push(LoggedEvent { seq, message: m }),
                Err(e) => warn!(seq, error = %e, "event_log: deserialize skipped"),
            }
        }
        debug!(count = out.len(), source = "cold", "replay served");
        out
    }

    /// Snapshot the hot ring length — surfaced in tests + metrics.
    pub fn hot_len(&self) -> usize {
        self.inner.hot.lock().len()
    }
}

/// Background retention job. Deletes events older than 7 days every
/// `interval` (default once per hour). Returns the JoinHandle so
/// `main.rs` can hold it for the process lifetime.
pub fn start_retention_job(log: EventLog, interval: Duration) -> tokio::task::JoinHandle<()> {
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(interval).await;
            const SEVEN_DAYS_MS: u64 = 7 * 24 * 60 * 60 * 1000;
            let cutoff = current_ms().saturating_sub(SEVEN_DAYS_MS);
            match log.inner.db.lock().await.prune_events_before(cutoff) {
                Ok(0) => debug!("retention: no rows to prune"),
                Ok(n) => info!(rows = n, "retention: pruned old events"),
                Err(e) => warn!(error = %e, "retention: prune failed"),
            }
        }
    })
}

fn server_message_type(m: &ServerMessage) -> &'static str {
    match m {
        ServerMessage::Response { .. } => "response",
        ServerMessage::TaskOutput { .. } => "task.output",
        ServerMessage::TaskStatus { .. } => "task.status",
        ServerMessage::TaskProgress { .. } => "task.progress",
        ServerMessage::TaskToolUse { .. } => "task.tool_use",
        ServerMessage::TaskArtifact { .. } => "task.artifact",
        ServerMessage::TaskAwaitingInput { .. } => "task.awaiting_input",
        ServerMessage::TaskUsage { .. } => "task.usage",
        ServerMessage::Pong { .. } => "pong",
        ServerMessage::TaskWatchersUpdate { .. } => "task.watchers_update",
        ServerMessage::HandoffReceived { .. } => "handoff.received",
        ServerMessage::TaskTakenOver { .. } => "task.taken_over",
        ServerMessage::TaskClientState { .. } => "task.client_state",
    }
}

fn task_id_of(m: &ServerMessage) -> Option<String> {
    match m {
        ServerMessage::TaskOutput { task_id, .. }
        | ServerMessage::TaskStatus { task_id, .. }
        | ServerMessage::TaskProgress { task_id, .. }
        | ServerMessage::TaskToolUse { task_id, .. }
        | ServerMessage::TaskArtifact { task_id, .. }
        | ServerMessage::TaskAwaitingInput { task_id, .. }
        | ServerMessage::TaskUsage { task_id, .. }
        | ServerMessage::TaskWatchersUpdate { task_id, .. }
        | ServerMessage::HandoffReceived { task_id, .. }
        | ServerMessage::TaskTakenOver { task_id, .. }
        | ServerMessage::TaskClientState { task_id, .. } => Some(task_id.clone()),
        ServerMessage::Response { .. } | ServerMessage::Pong { .. } => None,
    }
}

fn ts_ms_of(m: &ServerMessage) -> u64 {
    match m {
        ServerMessage::TaskOutput { ts_ms, .. }
        | ServerMessage::TaskStatus { ts_ms, .. }
        | ServerMessage::TaskProgress { ts_ms, .. }
        | ServerMessage::TaskToolUse { ts_ms, .. }
        | ServerMessage::TaskArtifact { ts_ms, .. }
        | ServerMessage::TaskAwaitingInput { ts_ms, .. }
        | ServerMessage::TaskUsage { ts_ms, .. }
        | ServerMessage::TaskWatchersUpdate { ts_ms, .. }
        | ServerMessage::HandoffReceived { ts_ms, .. }
        | ServerMessage::TaskTakenOver { ts_ms, .. }
        | ServerMessage::TaskClientState { ts_ms, .. } => *ts_ms,
        ServerMessage::Pong { ts_ms, .. } => *ts_ms,
        ServerMessage::Response { .. } => current_ms(),
    }
}

fn current_ms() -> u64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}
