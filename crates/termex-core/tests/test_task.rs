//! Tests for the shared Task DTO.
//!
//! Per CLAUDE.md "测试代码独立存放" — tests live here, not inline.

use termex_core::task::{AiCliKind, Task, TaskStatus};

#[test]
fn task_status_is_terminal() {
    assert!(!TaskStatus::Pending.is_terminal());
    assert!(!TaskStatus::PendingConfirmation.is_terminal());
    assert!(!TaskStatus::Running.is_terminal());
    assert!(TaskStatus::Succeeded.is_terminal());
    assert!(TaskStatus::Failed.is_terminal());
    assert!(TaskStatus::Cancelled.is_terminal());
}

#[test]
fn ai_cli_kind_default_commands() {
    assert_eq!(AiCliKind::ClaudeCode.default_command(), "claude");
    assert_eq!(AiCliKind::Codex.default_command(), "codex");
    assert_eq!(AiCliKind::Aider.default_command(), "aider");
    assert_eq!(AiCliKind::Generic.default_command(), "bash");
}

#[test]
fn task_serde_roundtrip() {
    let task = Task {
        id: "task-uuid".into(),
        ai_cli_kind: AiCliKind::ClaudeCode,
        prompt: "fix bug X".into(),
        workdir: Some("/repo".into()),
        status: TaskStatus::Running,
        started_at: "2026-05-23T10:00:00Z".into(),
        ended_at: None,
        exit_code: None,
        idle_timeout_sec: 30,
        output_tail: Some("running tests...".into()),
        error: None,
        server_id: Some("home-dev".into()),
    };
    let json = serde_json::to_string(&task).unwrap();
    let back: Task = serde_json::from_str(&json).unwrap();
    assert_eq!(task, back);
}

#[test]
fn task_status_serde_snake_case() {
    assert_eq!(
        serde_json::to_string(&TaskStatus::PendingConfirmation).unwrap(),
        "\"pending_confirmation\""
    );
    assert_eq!(
        serde_json::from_str::<TaskStatus>("\"succeeded\"").unwrap(),
        TaskStatus::Succeeded
    );
}

#[test]
fn ai_cli_kind_serde_snake_case() {
    assert_eq!(
        serde_json::to_string(&AiCliKind::ClaudeCode).unwrap(),
        "\"claude_code\""
    );
    assert_eq!(
        serde_json::from_str::<AiCliKind>("\"generic\"").unwrap(),
        AiCliKind::Generic
    );
}
