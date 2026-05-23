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

const PER_TASK_CHANNEL_CAPACITY: usize = 1024;

/// Multi-producer, multi-consumer event bus keyed by task id.
#[derive(Clone, Default)]
pub struct EventBus {
    inner: Arc<EventBusInner>,
}

#[derive(Default)]
struct EventBusInner {
    channels: RwLock<HashMap<String, broadcast::Sender<ServerMessage>>>,
    next_seq: AtomicU64,
}

impl EventBus {
    pub fn new() -> Self {
        Self::default()
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

    /// Broadcast a message for a given task. No-ops if no subscribers
    /// (and discards the message — daemon DB / event log persist the
    /// state separately).
    ///
    /// Returns the number of receivers that got the message (0 if
    /// nobody was listening).
    pub async fn broadcast(&self, task_id: &str, msg: ServerMessage) -> usize {
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
