//! Wire protocol DTOs for the termexd ⇄ client WebSocket stream.
//!
//! Both directions are tagged JSON; client→daemon messages carry a
//! `request_id` UUID echoed back in the matching `Response`.
//!
//! Endpoint: `ws://<remote>:7821/v1/stream` with
//! `Authorization: Bearer <token>` on the upgrade handshake.
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.2 for the
//! full message catalog. This module currently covers the v0.71.0
//! subset; v0.71.1 will add MCP-related variants (progress / artifact
//! / awaiting_input / usage / tool_use), v0.71.2 will add
//! `stream.replay`, v0.72.1 will add `task.decide` /
//! `task.pending_confirmation`.

use serde::{Deserialize, Serialize};

use crate::task::{AiCliKind, TaskStatus};

/// Messages from a client to the daemon. All carry a `request_id` for
/// correlation; the daemon emits a matching [`ServerMessage::Response`].
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ClientMessage {
    #[serde(rename = "task.assign")]
    TaskAssign {
        request_id: String,
        ai_cli: AiCliKind,
        prompt: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        workdir: Option<String>,
        #[serde(default = "default_idle_timeout")]
        idle_timeout_sec: u32,
    },

    #[serde(rename = "task.list")]
    TaskList {
        request_id: String,
        #[serde(default)]
        filter: TaskFilter,
    },

    #[serde(rename = "task.get")]
    TaskGet {
        request_id: String,
        task_id: String,
    },

    #[serde(rename = "task.subscribe")]
    TaskSubscribe {
        request_id: String,
        task_id: String,
    },

    #[serde(rename = "task.unsubscribe")]
    TaskUnsubscribe {
        request_id: String,
        task_id: String,
    },

    #[serde(rename = "task.cancel")]
    TaskCancel {
        request_id: String,
        task_id: String,
        #[serde(default = "default_cancel_signal")]
        signal: CancelSignal,
    },

    /// Placeholder used by v0.72.1's PendingConfirmation flow; the
    /// v0.71.0 daemon accepts but does nothing with it (the v0.71.0
    /// risk handler always auto-approves).
    #[serde(rename = "task.decide")]
    TaskDecide {
        request_id: String,
        task_id: String,
        decision: Decision,
    },

    #[serde(rename = "ping")]
    Ping {
        request_id: String,
        ts_ms: u64,
    },

    /// v0.71.2 — Ask the daemon to backfill events the client missed
    /// while disconnected. The daemon responds with the count via
    /// `Response`, then streams the actual events as normal
    /// (task.output / task.status / etc.) in seq order.
    #[serde(rename = "stream.replay")]
    StreamReplay {
        request_id: String,
        last_seq: u64,
        #[serde(default = "default_replay_limit")]
        limit: u32,
    },

    /// v0.74.2 — Client tells the daemon "this device exists; remember
    /// my name + platform". Sent immediately after the WS upgrade so
    /// the daemon can build the watchers / handoff target lists.
    #[serde(rename = "client.register_device")]
    ClientRegisterDevice {
        request_id: String,
        device_id: String,
        name: String,
        /// "ios" / "android" / "macos" / "linux" / "windows".
        platform: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        push_token: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        push_platform: Option<String>,
    },

    /// v0.74.2 — Push a task's deep link to another of the user's
    /// devices. The daemon routes to an online subscriber over WS or
    /// falls back to FCM (Pro) for offline targets.
    #[serde(rename = "handoff.send")]
    HandoffSend {
        request_id: String,
        task_id: String,
        target_device_id: String,
        deep_link: String,
    },

    /// v0.74.2 — Claim ownership of `task_id`. `expected_previous_owner`
    /// = Some when the UI already knows who owns the task and wants
    /// to detect concurrent takeovers; None for idempotent (re-)claim.
    #[serde(rename = "handoff.takeover")]
    HandoffTakeover {
        request_id: String,
        task_id: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        expected_previous_owner: Option<String>,
    },

    /// v0.74.2 — Broadcast UI state (scroll position, expanded
    /// artifacts) so other watchers can "Pull state from device X".
    #[serde(rename = "handoff.state_sync")]
    HandoffStateSync {
        request_id: String,
        task_id: String,
        ui_state: serde_json::Value,
    },
}

fn default_replay_limit() -> u32 {
    500
}

impl ClientMessage {
    pub fn request_id(&self) -> &str {
        match self {
            Self::TaskAssign { request_id, .. }
            | Self::TaskList { request_id, .. }
            | Self::TaskGet { request_id, .. }
            | Self::TaskSubscribe { request_id, .. }
            | Self::TaskUnsubscribe { request_id, .. }
            | Self::TaskCancel { request_id, .. }
            | Self::TaskDecide { request_id, .. }
            | Self::Ping { request_id, .. }
            | Self::StreamReplay { request_id, .. }
            | Self::ClientRegisterDevice { request_id, .. }
            | Self::HandoffSend { request_id, .. }
            | Self::HandoffTakeover { request_id, .. }
            | Self::HandoffStateSync { request_id, .. } => request_id,
        }
    }
}

fn default_idle_timeout() -> u32 {
    30
}

fn default_cancel_signal() -> CancelSignal {
    CancelSignal::Sigint
}

/// Filter passed to `task.list`. `Self::default()` returns "all
/// statuses" matching no specific state.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct TaskFilter {
    /// Match a specific [`TaskStatus`]. None = include all.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status: Option<TaskStatus>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CancelSignal {
    Sigint,
    Sigterm,
    Sigkill,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Decision {
    Approve,
    Deny,
}

/// Messages from the daemon to a client. `Response` is correlated with
/// a prior [`ClientMessage`] by `request_id`; the rest are unsolicited
/// pushes broadcast on the event bus.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ServerMessage {
    #[serde(rename = "response")]
    Response {
        request_id: String,
        ok: bool,
        #[serde(default)]
        data: serde_json::Value,
        #[serde(skip_serializing_if = "Option::is_none")]
        error: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        code: Option<String>,
    },

    /// Real-time PTY output chunk. `seq` is a monotonic per-daemon
    /// counter used by v0.71.2's event replay.
    #[serde(rename = "task.output")]
    TaskOutput {
        task_id: String,
        stream: OutputStream,
        data: String,
        seq: u64,
        ts_ms: u64,
    },

    /// Task lifecycle status change. `seq` added in v0.71.2 for
    /// event replay; defaults to 0 for forward-compat with v0.71.0
    /// producers (the replay path ignores 0-seq entries since they
    /// can't be reliably ordered).
    #[serde(rename = "task.status")]
    TaskStatus {
        task_id: String,
        status: TaskStatus,
        #[serde(skip_serializing_if = "Option::is_none")]
        exit_code: Option<i32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        duration_ms: Option<u64>,
        #[serde(default)]
        seq: u64,
        ts_ms: u64,
    },

    /// v0.71.1 — MCP progress notification. `ratio` is 0.0..=1.0;
    /// `note` is an optional human-readable status line.
    #[serde(rename = "task.progress")]
    TaskProgress {
        task_id: String,
        ratio: f32,
        #[serde(skip_serializing_if = "Option::is_none")]
        note: Option<String>,
        seq: u64,
        ts_ms: u64,
    },

    /// v0.71.1 — MCP tool-use trace. `stage` is "start" or
    /// "complete". `input_summary` / `output_summary` are
    /// daemon-side digests so the wire stays small even for tools
    /// that take/produce huge payloads.
    #[serde(rename = "task.tool_use")]
    TaskToolUse {
        task_id: String,
        tool: String,
        stage: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        input_summary: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        output_summary: Option<String>,
        seq: u64,
        ts_ms: u64,
    },

    /// v0.71.1 — Structured artifact emitted by an MCP-aware CLI.
    /// `payload` is the full JSON for the given `kind` (see
    /// `task::artifact::TaskArtifact` for the schemas).
    #[serde(rename = "task.artifact")]
    TaskArtifact {
        task_id: String,
        artifact_id: String,
        kind: String,
        payload: serde_json::Value,
        seq: u64,
        ts_ms: u64,
    },

    /// v0.71.1 — Task is paused waiting for user input. The Dart
    /// side renders an "Approve / Provide input" UI; subsequent
    /// `task.decide` (v0.72.1) resumes the task.
    #[serde(rename = "task.awaiting_input")]
    TaskAwaitingInput {
        task_id: String,
        prompt: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        schema: Option<serde_json::Value>,
        seq: u64,
        ts_ms: u64,
    },

    /// v0.71.1 — Token / cost reporting. Emitted whenever the MCP
    /// `usage` notification fires (typically once per LLM call).
    /// `estimated_cost_usd` is what the CLI reports; the daemon
    /// also records its own pricing-table-based estimate to the
    /// `task_costs` table in v0.74.1.
    #[serde(rename = "task.usage")]
    TaskUsage {
        task_id: String,
        input_tokens: u64,
        output_tokens: u64,
        model: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        estimated_cost_usd: Option<f64>,
        seq: u64,
        ts_ms: u64,
    },

    #[serde(rename = "pong")]
    Pong {
        request_id: String,
        ts_ms: u64,
    },

    /// v0.74.2 — Subscriber set for `task_id` changed (someone
    /// joined / left). Pushed only to current watchers.
    #[serde(rename = "task.watchers_update")]
    TaskWatchersUpdate {
        task_id: String,
        watchers: Vec<DeviceWireDto>,
        ts_ms: u64,
    },

    /// v0.74.2 — Target device receives the deep-link push. Sent
    /// only to the device named in `handoff.send`'s
    /// `target_device_id`.
    #[serde(rename = "handoff.received")]
    HandoffReceived {
        task_id: String,
        from_device: DeviceWireDto,
        deep_link: String,
        ts_ms: u64,
    },

    /// v0.74.2 — Previous owner is notified their task was claimed.
    #[serde(rename = "task.taken_over")]
    TaskTakenOver {
        task_id: String,
        new_owner: DeviceWireDto,
        ts_ms: u64,
    },

    /// v0.74.2 — Broadcast a watcher's UI state to other watchers
    /// so they can "Pull state from {name}".
    #[serde(rename = "task.client_state")]
    TaskClientState {
        task_id: String,
        from_device: DeviceWireDto,
        ui_state: serde_json::Value,
        ts_ms: u64,
    },
}

/// Trimmed device view used in wire payloads. Never includes the
/// push token — handoff messages broadcast widely and the token is
/// a credential.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeviceWireDto {
    pub id: String,
    pub name: String,
    pub platform: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OutputStream {
    Stdout,
    Stderr,
}

/// Convenience for `task.assign` callers building an AssignRequest
/// before serializing.
#[derive(Debug, Clone)]
pub struct AssignRequest {
    pub ai_cli: AiCliKind,
    pub prompt: String,
    pub workdir: Option<String>,
    pub idle_timeout_sec: u32,
}

impl Default for AssignRequest {
    fn default() -> Self {
        Self {
            ai_cli: AiCliKind::Generic,
            prompt: String::new(),
            workdir: None,
            idle_timeout_sec: 30,
        }
    }
}
