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
            | Self::Ping { request_id, .. } => request_id,
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

    /// Task lifecycle status change.
    #[serde(rename = "task.status")]
    TaskStatus {
        task_id: String,
        status: TaskStatus,
        #[serde(skip_serializing_if = "Option::is_none")]
        exit_code: Option<i32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        duration_ms: Option<u64>,
        ts_ms: u64,
    },

    #[serde(rename = "pong")]
    Pong {
        request_id: String,
        ts_ms: u64,
    },
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
