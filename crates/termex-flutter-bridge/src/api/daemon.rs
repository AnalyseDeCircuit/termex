//! FRB-exposed API for the v0.71.0 termexd daemon client.
//!
//! Mirrors the polling-based event pattern established by
//! `api/ssh.rs` + `frb_ssh_emitter`: the Dart side calls
//! `daemon_subscribe` to start streaming a task's events, then polls
//! `daemon_drain_events` periodically (typically off a Riverpod
//! stream provider tick) to pull queued events.
//!
//! For request/response calls (assign / list / get / cancel /
//! decide) we expose direct async wrappers around `DaemonClient`.
//!
//! Bridge handle model: `daemon_connect` returns an opaque `String`
//! handle id; subsequent calls take that id. The handle map lives in
//! a `OnceLock<DashMap<String, DaemonClient>>`. Disconnect drops the
//! client from the map.
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.8.

use std::sync::OnceLock;

use dashmap::DashMap;
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use tokio::sync::Mutex as AsyncMutex;
use uuid::Uuid;

use termex_core::daemon::{
    AssignRequest, CancelSignal, ClientError, DaemonClient, ServerMessage, TaskFilter,
};
use termex_core::task::{AiCliKind, Task, TaskStatus};

// ────────────────────────────────────────────────────────────────
// Handle registry
// ────────────────────────────────────────────────────────────────

fn handles() -> &'static DashMap<String, DaemonClient> {
    static H: OnceLock<DashMap<String, DaemonClient>> = OnceLock::new();
    H.get_or_init(DashMap::new)
}

// Event queue per handle, keyed by task_id.
type EventQueue = AsyncMutex<Vec<DaemonEvent>>;

fn event_queues() -> &'static DashMap<String, EventQueue> {
    static Q: OnceLock<DashMap<String, EventQueue>> = OnceLock::new();
    Q.get_or_init(DashMap::new)
}

// Track which (handle, task_id) pairs have an active pump task so we
// can de-dupe subscribe calls.
static SUBSCRIBED: Lazy<DashMap<(String, String), tokio::task::JoinHandle<()>>> =
    Lazy::new(DashMap::new);

// ────────────────────────────────────────────────────────────────
// DTOs the Dart side sees (FRB-friendly: snake_case, plain types).
// ────────────────────────────────────────────────────────────────

/// Mirror of `termex_core::task::AiCliKind` with the snake_case
/// wire labels the Dart side already uses (see v0.72.0 task UI).
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AiCliKindDto {
    ClaudeCode,
    Codex,
    Aider,
    Generic,
}

impl From<AiCliKindDto> for AiCliKind {
    fn from(v: AiCliKindDto) -> Self {
        match v {
            AiCliKindDto::ClaudeCode => Self::ClaudeCode,
            AiCliKindDto::Codex => Self::Codex,
            AiCliKindDto::Aider => Self::Aider,
            AiCliKindDto::Generic => Self::Generic,
        }
    }
}

impl From<AiCliKind> for AiCliKindDto {
    fn from(v: AiCliKind) -> Self {
        match v {
            AiCliKind::ClaudeCode => Self::ClaudeCode,
            AiCliKind::Codex => Self::Codex,
            AiCliKind::Aider => Self::Aider,
            AiCliKind::Generic => Self::Generic,
        }
    }
}

/// Mirror of `termex_core::task::TaskStatus`.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum TaskStatusDto {
    Pending,
    PendingConfirmation,
    Running,
    Succeeded,
    Failed,
    Cancelled,
}

impl From<TaskStatusDto> for TaskStatus {
    fn from(v: TaskStatusDto) -> Self {
        match v {
            TaskStatusDto::Pending => Self::Pending,
            TaskStatusDto::PendingConfirmation => Self::PendingConfirmation,
            TaskStatusDto::Running => Self::Running,
            TaskStatusDto::Succeeded => Self::Succeeded,
            TaskStatusDto::Failed => Self::Failed,
            TaskStatusDto::Cancelled => Self::Cancelled,
        }
    }
}

impl From<TaskStatus> for TaskStatusDto {
    fn from(v: TaskStatus) -> Self {
        match v {
            TaskStatus::Pending => Self::Pending,
            TaskStatus::PendingConfirmation => Self::PendingConfirmation,
            TaskStatus::Running => Self::Running,
            TaskStatus::Succeeded => Self::Succeeded,
            TaskStatus::Failed => Self::Failed,
            TaskStatus::Cancelled => Self::Cancelled,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskDto {
    pub id: String,
    pub ai_cli_kind: AiCliKindDto,
    pub prompt: String,
    pub workdir: Option<String>,
    pub status: TaskStatusDto,
    pub started_at: String,
    pub ended_at: Option<String>,
    pub exit_code: Option<i32>,
    pub idle_timeout_sec: u32,
    pub output_tail: Option<String>,
    pub error: Option<String>,
}

impl From<Task> for TaskDto {
    fn from(t: Task) -> Self {
        Self {
            id: t.id,
            ai_cli_kind: t.ai_cli_kind.into(),
            prompt: t.prompt,
            workdir: t.workdir,
            status: t.status.into(),
            started_at: t.started_at,
            ended_at: t.ended_at,
            exit_code: t.exit_code,
            idle_timeout_sec: t.idle_timeout_sec,
            output_tail: t.output_tail,
            error: t.error,
        }
    }
}

/// Tagged event the Dart side drains. Keep variants flat (no
/// discriminator union) — FRB tagged enums are still imperfect.
///
/// `kind` discriminator (Dart pattern-matches on it):
/// - `output` — raw PTY chunk
/// - `status` — terminal lifecycle change
/// - `progress` — MCP progress (v0.71.1+)
/// - `tool_use` — MCP tool-use trace (v0.71.1+)
/// - `artifact` — MCP structured artifact (v0.71.1+)
/// - `awaiting_input` — MCP wait-for-input prompt (v0.71.1+)
/// - `usage` — MCP token / cost report (v0.71.1+)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DaemonEvent {
    pub kind: String,
    pub task_id: String,
    pub seq: Option<u64>,
    pub ts_ms: u64,

    // output
    pub data: Option<String>,
    pub stream: Option<String>,

    // status
    pub status: Option<TaskStatusDto>,
    pub exit_code: Option<i32>,
    pub duration_ms: Option<u64>,

    // progress
    pub progress_ratio: Option<f32>,
    pub progress_note: Option<String>,

    // tool_use
    pub tool: Option<String>,
    pub tool_stage: Option<String>,
    pub tool_input_summary: Option<String>,
    pub tool_output_summary: Option<String>,

    // artifact
    pub artifact_id: Option<String>,
    pub artifact_kind: Option<String>,
    /// JSON-encoded payload (serialize/parse on the Dart side).
    pub artifact_payload_json: Option<String>,

    // awaiting_input
    pub awaiting_prompt: Option<String>,
    /// JSON-encoded schema (or None).
    pub awaiting_schema_json: Option<String>,

    // usage
    pub usage_input_tokens: Option<u64>,
    pub usage_output_tokens: Option<u64>,
    pub usage_model: Option<String>,
    pub usage_estimated_cost_usd: Option<f64>,
}

impl DaemonEvent {
    fn empty(kind: &str, task_id: String, seq: Option<u64>, ts_ms: u64) -> Self {
        Self {
            kind: kind.into(),
            task_id,
            seq,
            ts_ms,
            data: None,
            stream: None,
            status: None,
            exit_code: None,
            duration_ms: None,
            progress_ratio: None,
            progress_note: None,
            tool: None,
            tool_stage: None,
            tool_input_summary: None,
            tool_output_summary: None,
            artifact_id: None,
            artifact_kind: None,
            artifact_payload_json: None,
            awaiting_prompt: None,
            awaiting_schema_json: None,
            usage_input_tokens: None,
            usage_output_tokens: None,
            usage_model: None,
            usage_estimated_cost_usd: None,
        }
    }

    fn from_server_message(m: ServerMessage) -> Option<Self> {
        match m {
            ServerMessage::TaskOutput {
                task_id,
                stream,
                data,
                seq,
                ts_ms,
            } => {
                let mut e = Self::empty("output", task_id, Some(seq), ts_ms);
                e.data = Some(data);
                e.stream = Some(match stream {
                    termex_core::daemon::OutputStream::Stdout => "stdout".into(),
                    termex_core::daemon::OutputStream::Stderr => "stderr".into(),
                });
                Some(e)
            }
            ServerMessage::TaskStatus {
                task_id,
                status,
                exit_code,
                duration_ms,
                seq,
                ts_ms,
            } => {
                let mut e = Self::empty("status", task_id, Some(seq), ts_ms);
                e.status = Some(status.into());
                e.exit_code = exit_code;
                e.duration_ms = duration_ms;
                Some(e)
            }
            ServerMessage::TaskProgress {
                task_id,
                ratio,
                note,
                seq,
                ts_ms,
            } => {
                let mut e = Self::empty("progress", task_id, Some(seq), ts_ms);
                e.progress_ratio = Some(ratio);
                e.progress_note = note;
                Some(e)
            }
            ServerMessage::TaskToolUse {
                task_id,
                tool,
                stage,
                input_summary,
                output_summary,
                seq,
                ts_ms,
            } => {
                let mut e = Self::empty("tool_use", task_id, Some(seq), ts_ms);
                e.tool = Some(tool);
                e.tool_stage = Some(stage);
                e.tool_input_summary = input_summary;
                e.tool_output_summary = output_summary;
                Some(e)
            }
            ServerMessage::TaskArtifact {
                task_id,
                artifact_id,
                kind,
                payload,
                seq,
                ts_ms,
            } => {
                let mut e = Self::empty("artifact", task_id, Some(seq), ts_ms);
                e.artifact_id = Some(artifact_id);
                e.artifact_kind = Some(kind);
                e.artifact_payload_json = Some(payload.to_string());
                Some(e)
            }
            ServerMessage::TaskAwaitingInput {
                task_id,
                prompt,
                schema,
                seq,
                ts_ms,
            } => {
                let mut e = Self::empty("awaiting_input", task_id, Some(seq), ts_ms);
                e.awaiting_prompt = Some(prompt);
                e.awaiting_schema_json = schema.map(|v| v.to_string());
                Some(e)
            }
            ServerMessage::TaskUsage {
                task_id,
                input_tokens,
                output_tokens,
                model,
                estimated_cost_usd,
                seq,
                ts_ms,
            } => {
                let mut e = Self::empty("usage", task_id, Some(seq), ts_ms);
                e.usage_input_tokens = Some(input_tokens);
                e.usage_output_tokens = Some(output_tokens);
                e.usage_model = Some(model);
                e.usage_estimated_cost_usd = estimated_cost_usd;
                Some(e)
            }
            ServerMessage::Pong { .. } | ServerMessage::Response { .. } => None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DaemonProbeDto {
    Available(String /* version */),
    NotInstalled,
    Error(String),
}

// ────────────────────────────────────────────────────────────────
// FRB functions (Result<T, String> at the boundary)
// ────────────────────────────────────────────────────────────────

/// Connect to a termexd WebSocket and register the resulting client
/// in the handle map. Returns the handle id Dart should pass to
/// later calls. Always succeeds with a fresh id; the underlying
/// connect happens lazily inside the resulting client task.
pub async fn daemon_connect(ws_url: String, token: String) -> Result<String, String> {
    let client = DaemonClient::connect(&ws_url, &token)
        .await
        .map_err(map_err)?;
    let id = format!("daemon-{}", Uuid::new_v4().simple());
    handles().insert(id.clone(), client);
    event_queues().insert(id.clone(), AsyncMutex::new(Vec::new()));
    Ok(id)
}

/// Close a daemon connection and drop its handle.
pub async fn daemon_disconnect(handle_id: String) -> Result<(), String> {
    if let Some((_, client)) = handles().remove(&handle_id) {
        let _ = client.close().await;
    }
    event_queues().remove(&handle_id);
    // Abort any pump tasks for this handle.
    SUBSCRIBED.retain(|(h, _), handle| {
        if h == &handle_id {
            handle.abort();
            false
        } else {
            true
        }
    });
    Ok(())
}

pub async fn daemon_task_assign(
    handle_id: String,
    ai_cli: AiCliKindDto,
    prompt: String,
    workdir: Option<String>,
    idle_timeout_sec: u32,
) -> Result<String, String> {
    let client = get_client(&handle_id)?;
    client
        .task_assign(AssignRequest {
            ai_cli: ai_cli.into(),
            prompt,
            workdir,
            idle_timeout_sec,
        })
        .await
        .map_err(map_err)
}

pub async fn daemon_task_list(
    handle_id: String,
    status: Option<TaskStatusDto>,
) -> Result<Vec<TaskDto>, String> {
    let client = get_client(&handle_id)?;
    let tasks = client
        .task_list(TaskFilter {
            status: status.map(Into::into),
        })
        .await
        .map_err(map_err)?;
    Ok(tasks.into_iter().map(TaskDto::from).collect())
}

pub async fn daemon_task_get(
    handle_id: String,
    task_id: String,
) -> Result<Option<TaskDto>, String> {
    let client = get_client(&handle_id)?;
    let t = client.task_get(&task_id).await.map_err(map_err)?;
    Ok(t.map(TaskDto::from))
}

pub async fn daemon_task_cancel(
    handle_id: String,
    task_id: String,
    signal: String,
) -> Result<(), String> {
    let client = get_client(&handle_id)?;
    let sig = match signal.as_str() {
        "sigint" => CancelSignal::Sigint,
        "sigterm" => CancelSignal::Sigterm,
        "sigkill" => CancelSignal::Sigkill,
        other => return Err(format!("ERR_BAD_REQUEST: unknown signal {other}")),
    };
    client.task_cancel(&task_id, sig).await.map_err(map_err)
}

/// Begin streaming a task's events into the per-handle event queue.
/// Calling repeatedly with the same `(handle, task_id)` is a no-op
/// (we keep the existing pump task alive).
pub async fn daemon_subscribe(handle_id: String, task_id: String) -> Result<(), String> {
    let client = get_client(&handle_id)?;
    let key = (handle_id.clone(), task_id.clone());
    if SUBSCRIBED.contains_key(&key) {
        return Ok(());
    }
    let mut rx = client.subscribe(&task_id).await.map_err(map_err)?;
    let queues = event_queues();
    let handle_id_for_task = handle_id.clone();
    let task_id_for_task = task_id.clone();
    let pump = tokio::spawn(async move {
        while let Ok(msg) = rx.recv().await {
            let Some(evt) = DaemonEvent::from_server_message(msg) else {
                continue;
            };
            if let Some(queue) = queues.get(&handle_id_for_task) {
                queue.lock().await.push(evt);
            }
            // Stop pumping once we see a terminal status (drain still
            // works for the client to fetch the last events).
            // We can't easily inspect evt.status here without cloning;
            // for v0.71.0 the pump just runs until the broadcast is
            // dropped (DaemonClient closes).
            let _ = &task_id_for_task;
        }
    });
    SUBSCRIBED.insert(key, pump);
    Ok(())
}

/// Drain accumulated events for a handle. Returns up to
/// `max_events` (caller can pass 0 for "all"). Events are returned
/// in arrival order and removed from the queue.
pub async fn daemon_drain_events(
    handle_id: String,
    max_events: u32,
) -> Result<Vec<DaemonEvent>, String> {
    let Some(queue) = event_queues().get(&handle_id) else {
        return Err("ERR_BAD_REQUEST: unknown handle".into());
    };
    let mut q = queue.lock().await;
    if max_events == 0 || (max_events as usize) >= q.len() {
        Ok(std::mem::take(&mut *q))
    } else {
        let drained: Vec<_> = q.drain(..max_events as usize).collect();
        Ok(drained)
    }
}

/// Probe a remote machine for a `termexd` binary by running
/// `which termexd && termexd --version` over an SSH session the
/// Dart side has already opened (via `open_ssh_session`).
///
/// Returns the version string for `Available`, `NotInstalled` if
/// `which` fails, or `Error(msg)` for transport problems.
pub async fn daemon_probe(ssh_session_id: String) -> Result<DaemonProbeDto, String> {
    match ssh_exec_capture(&ssh_session_id, "which termexd >/dev/null && termexd --version").await
    {
        Ok(out) => {
            let line = out.lines().next().unwrap_or("").trim();
            if line.is_empty() {
                Ok(DaemonProbeDto::NotInstalled)
            } else {
                Ok(DaemonProbeDto::Available(line.to_string()))
            }
        }
        Err(e) if e.contains("exit") || e.contains("not found") => {
            Ok(DaemonProbeDto::NotInstalled)
        }
        Err(e) => Ok(DaemonProbeDto::Error(e)),
    }
}

/// Read the daemon's bearer token from the remote machine over an
/// existing SSH session. Returns the trimmed token.
///
/// The Dart side composes this with `port_forward_start` (local →
/// remote 127.0.0.1:7821) and then `daemon_connect(ws_url, token)`.
pub async fn daemon_read_token(ssh_session_id: String) -> Result<String, String> {
    let out = ssh_exec_capture(
        &ssh_session_id,
        "cat $HOME/.termex/daemon.token 2>/dev/null || true",
    )
    .await?;
    let token = out.trim().to_string();
    if token.is_empty() {
        Err("ERR_NOT_FOUND: ~/.termex/daemon.token is empty or missing".into())
    } else {
        Ok(token)
    }
}

/// Compose the canonical client-side WebSocket URL for a port that
/// the Dart side has already forwarded to remote 127.0.0.1:7821.
pub fn daemon_ws_url_for_local_port(local_port: u16) -> String {
    format!("ws://127.0.0.1:{local_port}/v1/stream")
}

/// SSH-tunnel-aware convenience: assumes the Dart side has already
/// established the SSH chain and a local port forward (local_port →
/// remote 127.0.0.1:7821) via the existing bridge APIs. This call
/// reads the token over SSH and then runs `daemon_connect`.
///
/// Returns the daemon handle id.
pub async fn daemon_connect_via_ssh(
    ssh_session_id: String,
    local_port: u16,
) -> Result<String, String> {
    let token = daemon_read_token(ssh_session_id).await?;
    let url = daemon_ws_url_for_local_port(local_port);
    daemon_connect(url, token).await
}

// ────────────────────────────────────────────────────────────────
// SSH helpers
// ────────────────────────────────────────────────────────────────

/// Run a one-shot command over an existing SSH session and return
/// its combined stdout. Errors include a hint indicating whether
/// the session was not registered or the command itself failed.
async fn ssh_exec_capture(ssh_session_id: &str, command: &str) -> Result<String, String> {
    let entry = crate::session_registry::REGISTRY
        .get(ssh_session_id)
        .ok_or_else(|| format!("ERR_NOT_FOUND: ssh session {ssh_session_id} not registered"))?;
    let guard = entry.session.lock().await;
    let session = guard
        .as_ref()
        .ok_or_else(|| "ERR_WS: ssh session closed".to_string())?;
    let (out, _exit) = session
        .exec_command(command)
        .await
        .map_err(|e| format!("ERR_WS: ssh exec: {e}"))?;
    Ok(out)
}

// ────────────────────────────────────────────────────────────────
// Handle helpers
// ────────────────────────────────────────────────────────────────

fn get_client(handle_id: &str) -> Result<DaemonClient, String> {
    handles()
        .get(handle_id)
        .map(|r| r.clone())
        .ok_or_else(|| "ERR_BAD_REQUEST: unknown handle".to_string())
}

/// Map a [`ClientError`] to the bridge's `"<code>: <message>"`
/// convention so the Dart side can pattern-match on the prefix.
fn map_err(e: ClientError) -> String {
    match e {
        ClientError::Connect(m) => format!("ERR_WS: {m}"),
        ClientError::Daemon { code, message } => format!("{code}: {message}"),
        ClientError::Timeout(d) => format!("ERR_TIMEOUT: {d:?}"),
        ClientError::Closed => "ERR_WS: connection closed".into(),
        ClientError::Codec(e) => format!("ERR_INTERNAL: codec: {e}"),
        ClientError::Internal(m) => format!("ERR_INTERNAL: {m}"),
    }
}
