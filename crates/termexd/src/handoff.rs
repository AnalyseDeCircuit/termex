//! v0.74.2 handoff runtime — the daemon-side counterpart of the
//! `termex_core::handoff` data primitives.
//!
//! Tracks which devices are currently connected, which devices are
//! watching which tasks, and routes [`HandoffSend`] / `Takeover`
//! messages between them. The persistence layer (device registry
//! + ownership lock) lives in `termex_core::handoff::{registry,
//! ownership}`; this module is the in-memory state machine layered
//! on top.
//!
//! The actual WS sink lives in `server.rs`; this module exposes a
//! thin trait (`DeviceSink`) so unit tests can substitute an
//! in-memory channel and assert routing behaviour without a real
//! socket.

use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use parking_lot::Mutex;
use tokio::sync::mpsc;

use termex_core::daemon::{DeviceWireDto, ServerMessage};
use termex_core::handoff::{
    ownership::{current_owner, try_takeover},
    registry as core_registry, Device, DevicePlatform, HandoffError, PushPlatform,
    TakeoverOutcome,
};

use crate::db::Database;

/// Lightweight identifier set used by the watcher map. Wrapper
/// around HashSet so the public API stays opaque if we ever swap
/// the inner storage.
#[derive(Debug, Default, Clone)]
pub struct WatcherSet {
    inner: HashSet<String>,
}

impl WatcherSet {
    pub fn insert(&mut self, device_id: String) -> bool {
        self.inner.insert(device_id)
    }
    pub fn remove(&mut self, device_id: &str) -> bool {
        self.inner.remove(device_id)
    }
    pub fn contains(&self, device_id: &str) -> bool {
        self.inner.contains(device_id)
    }
    pub fn len(&self) -> usize {
        self.inner.len()
    }
    pub fn is_empty(&self) -> bool {
        self.inner.is_empty()
    }
    pub fn iter(&self) -> impl Iterator<Item = &String> {
        self.inner.iter()
    }
}

/// Send a server message to a specific device's WS connection.
/// Implemented by `server.rs` over the real socket and by the test
/// harness over an mpsc channel.
pub trait DeviceSink: Send + Sync {
    fn send(&self, msg: ServerMessage);
}

/// Outcome surfaced by [`HandoffRuntime::send`] so the caller can
/// pick the right Response payload (delivered now vs queued for
/// reconnect vs needs FCM fallback).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DeliveryOutcome {
    /// Target was online; message handed off to its WS sink.
    DeliveredWs,
    /// Target is registered but currently offline. Caller should
    /// either fall through to FCM (Pro) or queue.
    Offline,
    /// Target device is not in the registry at all.
    UnknownTarget,
}

/// Inner runtime state — guarded by a single parking_lot mutex.
/// Operations are short (HashMap lookups, channel send) so a single
/// lock is fine; if contention shows up later split into per-task
/// shards.
#[derive(Default)]
struct Inner {
    /// device_id → connected WS sink (None when offline).
    connected: HashMap<String, Arc<dyn DeviceSink>>,
    /// task_id → set of watching device_ids.
    watchers: HashMap<String, WatcherSet>,
}

#[derive(Clone)]
pub struct HandoffRuntime {
    inner: Arc<Mutex<Inner>>,
    db: Arc<tokio::sync::Mutex<Database>>,
}

impl HandoffRuntime {
    pub fn new(db: Arc<tokio::sync::Mutex<Database>>) -> Self {
        Self {
            inner: Arc::new(Mutex::new(Inner::default())),
            db,
        }
    }

    /// Mark a device as connected, replacing any prior sink (e.g.
    /// after a reconnect). The first call also touches the
    /// persistent registry's `last_seen_at`.
    pub async fn on_connect(
        &self,
        device_id: &str,
        sink: Arc<dyn DeviceSink>,
    ) -> Result<(), HandoffError> {
        {
            let mut g = self.inner.lock();
            g.connected.insert(device_id.to_string(), sink);
        }
        let db = self.db.lock().await;
        let conn = db.conn();
        core_registry::ensure_schema(conn)?;
        let _ = core_registry::touch_last_seen(conn, device_id, &now_rfc3339());
        Ok(())
    }

    /// Mark a device as disconnected. Removes it from `connected`
    /// and from every watcher set; emits watcher updates for tasks
    /// the device was subscribed to so the remaining watchers'
    /// counts stay accurate.
    pub fn on_disconnect(&self, device_id: &str) -> Vec<String> {
        let mut g = self.inner.lock();
        g.connected.remove(device_id);
        let mut touched = Vec::new();
        for (task_id, set) in g.watchers.iter_mut() {
            if set.remove(device_id) {
                touched.push(task_id.clone());
            }
        }
        touched
    }

    /// Register/refresh a device row + connect-time metadata. Used
    /// by the `client.register_device` handler.
    pub async fn register_device(
        &self,
        device_id: &str,
        name: &str,
        platform: &str,
        push_token: Option<&str>,
        push_platform: Option<&str>,
    ) -> Result<(), HandoffError> {
        let plat = DevicePlatform::parse(platform).ok_or_else(|| {
            HandoffError::UnknownDevice(format!("unknown platform: {platform}"))
        })?;
        let push_plat = match push_platform {
            None => None,
            Some("ios_apns") => Some(PushPlatform::IosApns),
            Some("android_fcm") => Some(PushPlatform::AndroidFcm),
            Some(other) => {
                return Err(HandoffError::UnknownDevice(format!(
                    "unknown push_platform: {other}"
                )))
            }
        };
        let now = now_rfc3339();
        let device = Device {
            id: device_id.to_string(),
            name: name.to_string(),
            platform: plat,
            first_seen_at: now.clone(),
            last_seen_at: now,
            push_token: push_token.map(str::to_string),
            push_platform: push_plat,
        };
        let db = self.db.lock().await;
        let conn = db.conn();
        core_registry::ensure_schema(conn)?;
        core_registry::upsert(conn, &device)
    }

    /// Add `device_id` to `task_id`'s watcher set. Returns the new
    /// set so the caller can broadcast a [`task.watchers_update`].
    pub async fn subscribe(&self, task_id: &str, device_id: &str) -> Vec<DeviceWireDto> {
        let ids: Vec<String> = {
            let mut g = self.inner.lock();
            g.watchers
                .entry(task_id.to_string())
                .or_default()
                .insert(device_id.to_string());
            g.watchers
                .get(task_id)
                .map(|s| s.iter().cloned().collect())
                .unwrap_or_default()
        };
        self.enrich(ids).await
    }

    /// Inverse of [`subscribe`]. Returns the updated set so the
    /// caller can rebroadcast.
    pub async fn unsubscribe(&self, task_id: &str, device_id: &str) -> Vec<DeviceWireDto> {
        let ids: Vec<String> = {
            let mut g = self.inner.lock();
            if let Some(set) = g.watchers.get_mut(task_id) {
                set.remove(device_id);
            }
            g.watchers
                .get(task_id)
                .map(|s| s.iter().cloned().collect())
                .unwrap_or_default()
        };
        self.enrich(ids).await
    }

    pub async fn watchers(&self, task_id: &str) -> Vec<DeviceWireDto> {
        let ids: Vec<String> = {
            let g = self.inner.lock();
            g.watchers
                .get(task_id)
                .map(|s| s.iter().cloned().collect())
                .unwrap_or_default()
        };
        self.enrich(ids).await
    }

    /// Synchronous watcher count — used by `on_disconnect` to avoid
    /// holding the parking_lot mutex across an `.await`.
    pub fn watcher_ids(&self, task_id: &str) -> Vec<String> {
        let g = self.inner.lock();
        g.watchers
            .get(task_id)
            .map(|s| s.iter().cloned().collect())
            .unwrap_or_default()
    }

    async fn enrich(&self, ids: Vec<String>) -> Vec<DeviceWireDto> {
        if ids.is_empty() {
            return Vec::new();
        }
        let db = self.db.lock().await;
        let conn = db.conn();
        // ensure_schema is idempotent + cheap; covers test paths
        // that build the runtime against a brand-new in-memory DB.
        let _ = core_registry::ensure_schema(conn);
        ids.into_iter()
            .map(|id| {
                let name_plat = core_registry::get(conn, &id)
                    .ok()
                    .flatten()
                    .map(|d| (d.name, d.platform.as_str().to_string()))
                    .unwrap_or_else(|| (id.clone(), "unknown".into()));
                DeviceWireDto {
                    id,
                    name: name_plat.0,
                    platform: name_plat.1,
                }
            })
            .collect()
    }

    /// Route a `handoff.send` to the target device. Returns the
    /// delivery outcome so the handler can pick the wire reply.
    pub async fn send_handoff(
        &self,
        task_id: &str,
        from_device: DeviceWireDto,
        target_device_id: &str,
        deep_link: &str,
    ) -> DeliveryOutcome {
        let sink = {
            let g = self.inner.lock();
            g.connected.get(target_device_id).cloned()
        };
        let target_known = self.target_registered(target_device_id).await;
        match (sink, target_known) {
            (Some(s), _) => {
                s.send(ServerMessage::HandoffReceived {
                    task_id: task_id.to_string(),
                    from_device,
                    deep_link: deep_link.to_string(),
                    ts_ms: now_ms(),
                });
                DeliveryOutcome::DeliveredWs
            }
            (None, true) => DeliveryOutcome::Offline,
            (None, false) => DeliveryOutcome::UnknownTarget,
        }
    }

    /// Push a `task.taken_over` to the prior owner (if connected).
    /// Returns the new owner snapshot that should be returned to
    /// the takeover caller, or RaceLost.
    pub async fn try_take_over(
        &self,
        task_id: &str,
        new_owner: &DeviceWireDto,
        expected_previous_owner: Option<&str>,
    ) -> Result<TakeoverOutcome, HandoffError> {
        let now = now_rfc3339();
        let mut db = self.db.lock().await;
        let outcome = {
            let conn = db.conn_mut();
            try_takeover(conn, task_id, &new_owner.id, expected_previous_owner, &now)?
        };
        drop(db);

        if let TakeoverOutcome::Won {
            previous_owner_id: Some(prev),
        } = &outcome
        {
            // Notify previous owner if they're still online.
            let g = self.inner.lock();
            if let Some(sink) = g.connected.get(prev) {
                sink.send(ServerMessage::TaskTakenOver {
                    task_id: task_id.to_string(),
                    new_owner: new_owner.clone(),
                    ts_ms: now_ms(),
                });
            }
        }
        Ok(outcome)
    }

    /// Look up the current owner of a task (used by `task.get`
    /// responses + UI hints).
    pub async fn current_owner(&self, task_id: &str) -> Result<Option<String>, HandoffError> {
        let db = self.db.lock().await;
        current_owner(db.conn(), task_id)
    }

    /// Broadcast a [`TaskClientState`] from `from_device` to every
    /// other watcher of `task_id`. Returns how many devices the
    /// payload was actually fanned out to (excluding the sender).
    pub fn broadcast_state(
        &self,
        task_id: &str,
        from_device: DeviceWireDto,
        ui_state: serde_json::Value,
    ) -> usize {
        let g = self.inner.lock();
        let set = match g.watchers.get(task_id) {
            Some(s) => s,
            None => return 0,
        };
        let mut count = 0;
        let payload = ServerMessage::TaskClientState {
            task_id: task_id.to_string(),
            from_device: from_device.clone(),
            ui_state,
            ts_ms: now_ms(),
        };
        for device_id in set.iter() {
            if device_id == &from_device.id {
                continue;
            }
            if let Some(sink) = g.connected.get(device_id) {
                sink.send(payload.clone());
                count += 1;
            }
        }
        count
    }

    /// Test helper — inserts a minimal `tasks` row so the
    /// ownership-lock SQL has something to UPDATE. Public so
    /// path-included integration tests can call it; not used in
    /// production code paths.
    pub async fn insert_task_for_test(&self, task_id: &str) {
        let db = self.db.lock().await;
        let _ = db.conn().execute(
            "INSERT OR REPLACE INTO tasks
                 (id, ai_cli_kind, prompt, status, started_at, idle_timeout_sec)
             VALUES (?1, 'claude_code', '', 'running',
                     '2026-05-23T00:00:00Z', 30)",
            rusqlite::params![task_id],
        );
    }

    async fn target_registered(&self, device_id: &str) -> bool {
        let db = self.db.lock().await;
        let conn = db.conn();
        core_registry::ensure_schema(conn).ok();
        core_registry::get(conn, device_id)
            .map(|d| d.is_some())
            .unwrap_or(false)
    }
}

fn now_rfc3339() -> String {
    chrono::Utc::now().to_rfc3339()
}

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

/// Test-only mpsc-backed [`DeviceSink`] used by integration tests.
/// Public so the integration test crate (which doesn't see
/// `cfg(test)` of the bin crate) can grab it via path-include.
pub struct ChannelSink {
    tx: mpsc::UnboundedSender<ServerMessage>,
}

impl ChannelSink {
    pub fn new() -> (Arc<Self>, mpsc::UnboundedReceiver<ServerMessage>) {
        let (tx, rx) = mpsc::unbounded_channel();
        (Arc::new(Self { tx }), rx)
    }
}

impl DeviceSink for ChannelSink {
    fn send(&self, msg: ServerMessage) {
        let _ = self.tx.send(msg);
    }
}
