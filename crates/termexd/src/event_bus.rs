//! In-process event bus that fans task events out to subscribed WS
//! clients.
//!
//! Per task we keep a `tokio::sync::broadcast` channel. Subscribers
//! join on demand; channel capacity is fixed (lagging subscribers
//! drop oldest events rather than block the producer).
//!
//! Sequence numbers are assigned monotonically per daemon process
//! (used by v0.71.2's event replay on reconnect).
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.6.

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

use tokio::sync::{broadcast, RwLock};

use termex_core::daemon::ServerMessage;

use crate::event_log::EventLog;

const PER_TASK_CHANNEL_CAPACITY: usize = 1024;

/// Multi-producer, multi-consumer event bus keyed by task id.
///
/// v0.71.2: also persists every broadcast through an optional
/// [`EventLog`] so reconnecting clients can replay missed events.
#[derive(Clone, Default)]
pub struct EventBus {
    inner: Arc<EventBusInner>,
}

#[derive(Default)]
struct EventBusInner {
    channels: RwLock<HashMap<String, broadcast::Sender<ServerMessage>>>,
    next_seq: AtomicU64,
    /// Optional event log. When `Some`, every broadcast is persisted
    /// before fan-out. Test helpers may leave this `None` for speed.
    event_log: parking_lot::Mutex<Option<EventLog>>,
}

impl EventBus {
    pub fn new() -> Self {
        let bus = Self::default();
        // Start the seq counter at 1 so `stream.replay(0, …)` (the
        // canonical "give me everything from the start" query)
        // matches the very first event.
        bus.inner.next_seq.store(1, Ordering::SeqCst);
        bus
    }

    /// Attach an [`EventLog`] so subsequent broadcasts are persisted
    /// for replay. Idempotent; replaces any prior log.
    pub fn attach_event_log(&self, log: EventLog) {
        *self.inner.event_log.lock() = Some(log);
    }

    /// Reserve a monotonic sequence number. Used by callers building
    /// `task.output` / `task.status` messages so v0.71.2's replay
    /// path can dedupe.
    pub fn next_seq(&self) -> u64 {
        self.inner.next_seq.fetch_add(1, Ordering::SeqCst)
    }

    /// Subscribe to a task's events. Creates the channel on demand.
    pub async fn subscribe(&self, task_id: &str) -> broadcast::Receiver<ServerMessage> {
        let mut chans = self.inner.channels.write().await;
        let tx = chans
            .entry(task_id.to_string())
            .or_insert_with(|| broadcast::channel(PER_TASK_CHANNEL_CAPACITY).0);
        tx.subscribe()
    }

    /// Broadcast a message for a given task. Persists to the
    /// attached [`EventLog`] (if any) BEFORE fan-out so reconnecting
    /// clients can always replay what live subscribers saw.
    ///
    /// Returns the number of receivers that got the message (0 if
    /// nobody was listening or no channel has been registered).
    pub async fn broadcast(&self, task_id: &str, msg: ServerMessage) -> usize {
        // Capture the seq from inside the message if present; this
        // is the same value the producer pre-allocated via
        // `next_seq()`.
        if let Some(seq) = seq_of(&msg) {
            let log_opt = self.inner.event_log.lock().clone();
            if let Some(log) = log_opt {
                log.push(seq, &msg).await;
            }
        }
        let chans = self.inner.channels.read().await;
        match chans.get(task_id) {
            Some(tx) => tx.send(msg).unwrap_or(0),
            None => 0,
        }
    }

    /// Number of currently-tracked task channels. Useful in tests
    /// and in the `/metrics` endpoint.
    pub async fn active_channel_count(&self) -> usize {
        self.inner.channels.read().await.len()
    }

    /// Drop the channel for a task. Called when the task reaches a
    /// terminal state and no clients are subscribed any more.
    /// Defensive — leaving channels around is harmless but bounded
    /// memory bothers some users.
    #[allow(dead_code)]
    pub async fn drop_channel(&self, task_id: &str) {
        self.inner.channels.write().await.remove(task_id);
    }
}

/// Extract the `seq` field from any v0.71.2+ task-scoped server
/// message. Returns `None` for variants that have no seq (Response,
/// Pong) — those are never replayed.
fn seq_of(m: &ServerMessage) -> Option<u64> {
    match m {
        ServerMessage::TaskOutput { seq, .. }
        | ServerMessage::TaskStatus { seq, .. }
        | ServerMessage::TaskProgress { seq, .. }
        | ServerMessage::TaskToolUse { seq, .. }
        | ServerMessage::TaskArtifact { seq, .. }
        | ServerMessage::TaskAwaitingInput { seq, .. }
        | ServerMessage::TaskUsage { seq, .. } => Some(*seq),
        ServerMessage::Response { .. } | ServerMessage::Pong { .. } => None,
    }
}
