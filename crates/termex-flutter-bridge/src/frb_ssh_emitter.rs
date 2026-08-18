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

/// Pushes stdout bytes directly — used by local PTY reader thread.
pub fn push_stdout(session_id: &str, data: Vec<u8>) {
    enqueue(session_id, SshStreamEvent::stdout(data));
}

/// Pushes a disconnected event directly — used by local PTY reader thread.
pub fn push_disconnected(session_id: &str) {
    enqueue(session_id, SshStreamEvent::disconnected());
}

/// Pushes an event to the session's queue if it is still registered.
///
/// Also the capture point for session recording. Every byte the terminal
/// shows passes through here — the SSH channel reader, the local PTY reader
/// and the chain emitter all funnel into it — so it is the one place that
/// sees the same stream the user does. The Tauri build hooked the equivalent
/// spot in its SSH read loop; the Flutter bridge never did, which is why
/// recordings were empty files.
fn enqueue(session_id: &str, event: SshStreamEvent) {
    if event.kind == "stdout" && !event.data.is_empty() {
        record_stdout(session_id, &event.data);
    }
    if let Some(entry) = QUEUES.get(session_id) {
        if let Ok(mut q) = entry.lock() {
            q.push_back(event);
        }
    }
}

/// Hands terminal output to the recorder without blocking the reader.
///
/// `enqueue` is synchronous and runs on the PTY reader thread and inside
/// russh callbacks, while `RecorderRegistry::record_output` is async. Blocking
/// on it here would stall the terminal, so the work is handed to the runtime
/// and the caller returns immediately.
fn record_stdout(session_id: &str, data: &[u8]) {
    // Recording is off for almost every session; skip the allocation and the
    // spawn unless this one is armed.
    if !ACTIVE_RECORDINGS.contains(session_id) {
        return;
    }
    let sid = session_id.to_string();
    let text = String::from_utf8_lossy(data).into_owned();
    if let Ok(handle) = tokio::runtime::Handle::try_current() {
        handle.spawn(async move {
            let within_limit = crate::api::recording::RECORDER
                .record_output(&sid, &text)
                .await;
            // The recorder reports its size cap by returning false; stop
            // rather than growing the file unbounded.
            if !within_limit {
                let _ = crate::api::recording::RECORDER.stop(&sid).await;
                ACTIVE_RECORDINGS.remove(&sid);
            }
        });
    }
}

/// Sessions currently being recorded.
///
/// A synchronous set so `enqueue` can check it without awaiting the
/// recorder's async lock on every chunk of output.
pub static ACTIVE_RECORDINGS: Lazy<dashmap::DashSet<String>> =
    Lazy::new(dashmap::DashSet::new);

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
