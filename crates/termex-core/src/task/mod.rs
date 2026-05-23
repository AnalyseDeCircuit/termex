//! Task model shared between termexd and clients.
//!
//! v0.71.0 — defines the `Task` DTO + `TaskStatus` / `AiCliKind` enums.
//! v0.71.1 will add the `task::adapter` module (CompletionDetector + the
//! 4 AI CLI adapters). v0.72.1 will add `task::risk` (RiskScorer).
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.3 for design.

use serde::{Deserialize, Serialize};

/// A single AI long-running task tracked by termexd.
///
/// The daemon is the authoritative source; clients cache rows in their
/// own `tasks` table (migration #26) for offline browsing.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Task {
    /// UUID v4 generated on assignment.
    pub id: String,

    /// Which AI CLI we asked to run this task.
    pub ai_cli_kind: AiCliKind,

    /// The natural-language prompt the user typed (or spoke) into the
    /// Assign Task sheet.
    pub prompt: String,

    /// Optional working directory passed to the AI CLI (`--workdir`).
    pub workdir: Option<String>,

    /// Current lifecycle state.
    pub status: TaskStatus,

    /// RFC3339 timestamp the task was assigned (status moves out of
    /// Pending into Running or PendingConfirmation).
    pub started_at: String,

    /// RFC3339 timestamp of the final terminal state (Succeeded /
    /// Failed / Cancelled). None while still running.
    pub ended_at: Option<String>,

    /// Process exit code if known. May be Some(0) for AI CLIs that
    /// always return 0 regardless of semantic success — see
    /// `task::adapter` for per-CLI completion semantics (v0.71.1).
    pub exit_code: Option<i32>,

    /// Idle timeout (seconds) passed to the supervisor — if the PTY
    /// child produces no output for this long, the IdleAndExitDetector
    /// fires an idle event (does not auto-kill).
    pub idle_timeout_sec: u32,

    /// The last ~8KB of stdout, for card-preview rendering when no
    /// structured artifact is available. Bounded by the daemon.
    pub output_tail: Option<String>,

    /// Human-readable error message if `status == Failed`.
    pub error: Option<String>,
}

/// Lifecycle state of a [`Task`].
///
/// `Pending` is rarely seen by clients — the daemon transitions into it
/// just long enough to insert the row, then immediately to either
/// `PendingConfirmation` (v0.72.1, when risk gating is enabled) or
/// `Running`.
///
/// `AwaitingInput` is reserved for the MCP `wait_for_input` event
/// (v0.71.1). The daemon emits a separate `task.awaiting_input` WS
/// message; the status stays `Running` to avoid confusing legacy
/// clients that don't model `AwaitingInput`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskStatus {
    Pending,
    PendingConfirmation,
    Running,
    Succeeded,
    Failed,
    Cancelled,
}

impl TaskStatus {
    /// Returns true for terminal states (no further state transitions
    /// expected; safe to remove from "active tasks" views).
    pub fn is_terminal(&self) -> bool {
        matches!(self, Self::Succeeded | Self::Failed | Self::Cancelled)
    }
}

/// Identifies which AI CLI is running this task. Used by the supervisor
/// to choose the launch command and by `task::adapter` to pick the
/// right completion detector.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiCliKind {
    ClaudeCode,
    Codex,
    Aider,
    /// Arbitrary shell command. Completion detected via
    /// `IdleAndExitDetector` only (no protocol-aware adapter).
    Generic,
}

impl AiCliKind {
    /// Default shell command template. Users can override via Settings
    /// (server-level or global; v0.72.1+ allows custom commands).
    ///
    /// The actual launch flags depend on whether termexd negotiates
    /// MCP successfully (v0.71.1) — see
    /// `termexd::supervisor::build_command`.
    pub fn default_command(&self) -> &'static str {
        match self {
            Self::ClaudeCode => "claude",
            Self::Codex => "codex",
            Self::Aider => "aider",
            Self::Generic => "bash",
        }
    }
}

#[cfg(test)]
mod tests {
    // Test cases live under crates/termex-core/tests/ per CLAUDE.md
    // ("测试代码独立存放"); see tests/test_task.rs.
}
