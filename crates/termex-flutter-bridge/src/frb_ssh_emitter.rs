use std::collections::VecDeque;
use std::sync::Mutex;

use dashmap::DashMap;
use once_cell::sync::Lazy;
use termex_core::ssh::event_emitter::SshEventEmitter;

/// Event delivered to the Flutter side.
///
/// The Dart layer pattern-matches on the `kind` field and extracts the
/// relevant payload. Kept as a flat struct (not a nested enum) so that
/// `flutter_rust_bridge` v2 codegen produces an ergonomic Dart class
/// without union-type gymnastics.
#[derive(Debug, Clone)]
pub struct SshStreamEvent {
    /// One of: `stdout`, `exit`, `disconnected`, `port_forward`.
    pub kind: String,
    /// Terminal bytes when `kind == "stdout"`. Empty otherwise.
    pub data: Vec<u8>,
    /// Exit code when `kind == "exit"`. Zero otherwise.
    pub exit_code: u32,
    /// Named event identifier (port-forward notifications).
    pub event: String,
    /// Arbitrary JSON payload for `port_forward` events.
    pub payload: String,
}

impl SshStreamEvent {
    pub fn stdout(data: Vec<u8>) -> Self {
        Self {
            kind: "stdout".into(),
            data,
            exit_code: 0,
            event: String::new(),
            payload: String::new(),
        }
    }

    pub fn exit(code: u32) -> Self {
        Self {
            kind: "exit".into(),
            data: Vec::new(),
            exit_code: code,
            event: String::new(),
            payload: String::new(),
        }
    }

    pub fn disconnected() -> Self {
        Self {
            kind: "disconnected".into(),
            data: Vec::new(),
            exit_code: 0,
            event: String::new(),
            payload: String::new(),
        }
    }

    pub fn port_forward(event: String, payload: String) -> Self {
        Self {
            kind: "port_forward".into(),
            data: Vec::new(),
            exit_code: 0,
            event,
            payload,
        }
    }
}

/// Per-session event queue.
///
/// The Dart side polls via `poll_ssh_events(session_id)` at ~60fps. This
/// deliberately avoids FRB v2's codegen-generated `StreamSink<T>` so the
/// bridge compiles without running `flutter_rust_bridge_codegen` first.
/// Latency is bounded by the poll interval; terminal UX with 16ms polls
/// is indistinguishable from a push-based stream.
static QUEUES: Lazy<DashMap<String, Mutex<VecDeque<SshStreamEvent>>>> =
    Lazy::new(DashMap::new);

/// Registers an empty queue for a new session. Called at `open_ssh_session`.
pub fn register_session(session_id: String) {
    QUEUES.insert(session_id, Mutex::new(VecDeque::new()));
}

/// Removes the queue for a closed session.
pub fn unregister_session(session_id: &str) {
    QUEUES.remove(session_id);
}

/// Drains the per-session queue. Called by the Dart polling task.
pub fn drain(session_id: &str) -> Vec<SshStreamEvent> {
    let Some(entry) = QUEUES.get(session_id) else {
        return Vec::new();
    };
    let Ok(mut q) = entry.lock() else {
        return Vec::new();
    };
    q.drain(..).collect()
}

/// Pushes an event to the session's queue if it is still registered.
fn enqueue(session_id: &str, event: SshStreamEvent) {
    if let Some(entry) = QUEUES.get(session_id) {
        if let Ok(mut q) = entry.lock() {
            q.push_back(event);
        }
    }
}

/// FRB-side implementation of `SshEventEmitter`.
///
/// Routes channel events into the per-session queue for pull-based
/// delivery to Dart. The emitter itself is stateless — all routing goes
/// through the global `QUEUES` registry so cloning the `Arc` does not
/// duplicate state.
pub struct FrbSshEmitter;

#[async_trait::async_trait]
impl SshEventEmitter for FrbSshEmitter {
    fn emit_stdout(&self, session_id: &str, data: Vec<u8>) {
        enqueue(session_id, SshStreamEvent::stdout(data));
    }

    fn emit_exit_status(&self, session_id: &str, exit_code: u32) {
        enqueue(session_id, SshStreamEvent::exit(exit_code));
    }

    fn emit_disconnected(&self, session_id: &str) {
        enqueue(session_id, SshStreamEvent::disconnected());
        // Queue stays alive one more poll so Dart sees the disconnected
        // event; the Dart side calls `close_ssh_session` afterwards, which
        // invokes `unregister_session`.
    }

    fn emit_port_forward_event(&self, event: &str, payload: &str) {
        // Port-forward notifications are broadcast to all active queues;
        // the Dart side filters by payload when it matters.
        for entry in QUEUES.iter() {
            if let Ok(mut q) = entry.value().lock() {
                q.push_back(SshStreamEvent::port_forward(
                    event.to_string(),
                    payload.to_string(),
                ));
            }
        }
    }

    async fn on_data_side_effect(&self, _session_id: &str, _data: &[u8]) {
        // No recording in the bridge context — that remains a Tauri concern.
    }
}
