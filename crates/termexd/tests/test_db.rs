//! Tests for daemon-side SQLite storage.

#[path = "../src/db.rs"]
#[allow(dead_code)]
mod db;

#[path = "../src/error.rs"]
#[allow(dead_code)]
mod error;

use termex_core::task::{AiCliKind, Task, TaskStatus};

use db::Database;

fn sample_task(id: &str, status: TaskStatus) -> Task {
    Task {
        id: id.into(),
        ai_cli_kind: AiCliKind::ClaudeCode,
        prompt: format!("prompt for {id}"),
        workdir: Some("/repo".into()),
        status,
        started_at: "2026-05-23T10:00:00Z".into(),
        ended_at: None,
        exit_code: None,
        idle_timeout_sec: 30,
        output_tail: None,
        error: None,
        server_id: None,
    }
}

#[test]
fn in_memory_db_creates_current_schema_version() {
    let db = Database::in_memory().unwrap();
    assert_eq!(db.schema_version().unwrap(), db::DAEMON_DB_SCHEMA_VERSION);
}

#[test]
fn insert_then_get_round_trip() {
    let db = Database::in_memory().unwrap();
    let task = sample_task("t1", TaskStatus::Running);
    db.insert_task(&task).unwrap();
    let fetched = db.get_task("t1").unwrap().expect("task exists");
    assert_eq!(fetched, task);
}

#[test]
fn get_nonexistent_returns_none() {
    let db = Database::in_memory().unwrap();
    assert!(db.get_task("missing").unwrap().is_none());
}

#[test]
fn list_tasks_filters_by_status() {
    let db = Database::in_memory().unwrap();
    db.insert_task(&sample_task("t-run", TaskStatus::Running))
        .unwrap();
    db.insert_task(&sample_task("t-done", TaskStatus::Succeeded))
        .unwrap();
    db.insert_task(&sample_task("t-fail", TaskStatus::Failed))
        .unwrap();

    let all = db.list_tasks(None).unwrap();
    assert_eq!(all.len(), 3);

    let only_running = db.list_tasks(Some(TaskStatus::Running)).unwrap();
    assert_eq!(only_running.len(), 1);
    assert_eq!(only_running[0].id, "t-run");

    let none_pending = db.list_tasks(Some(TaskStatus::Pending)).unwrap();
    assert!(none_pending.is_empty());
}

#[test]
fn list_tasks_orders_by_started_at_desc() {
    let db = Database::in_memory().unwrap();
    let mut old = sample_task("old", TaskStatus::Succeeded);
    old.started_at = "2026-01-01T00:00:00Z".into();
    let mut new = sample_task("new", TaskStatus::Succeeded);
    new.started_at = "2026-12-31T00:00:00Z".into();

    db.insert_task(&old).unwrap();
    db.insert_task(&new).unwrap();

    let all = db.list_tasks(None).unwrap();
    assert_eq!(all[0].id, "new");
    assert_eq!(all[1].id, "old");
}

#[test]
fn update_status_changes_terminal_fields() {
    let db = Database::in_memory().unwrap();
    db.insert_task(&sample_task("t1", TaskStatus::Running))
        .unwrap();

    db.update_status(
        "t1",
        TaskStatus::Succeeded,
        Some("2026-05-23T11:00:00Z"),
        Some(0),
        None,
    )
    .unwrap();

    let fetched = db.get_task("t1").unwrap().unwrap();
    assert_eq!(fetched.status, TaskStatus::Succeeded);
    assert_eq!(fetched.ended_at.as_deref(), Some("2026-05-23T11:00:00Z"));
    assert_eq!(fetched.exit_code, Some(0));
}

#[test]
fn update_status_missing_id_errors() {
    let db = Database::in_memory().unwrap();
    let res = db.update_status("missing", TaskStatus::Failed, None, Some(1), None);
    assert!(res.is_err(), "must error on missing id");
}

#[test]
fn ai_cli_kind_round_trip_all_variants() {
    let db = Database::in_memory().unwrap();
    for (kind, id) in [
        (AiCliKind::ClaudeCode, "claude"),
        (AiCliKind::Codex, "codex"),
        (AiCliKind::Aider, "aider"),
        (AiCliKind::Generic, "generic"),
    ] {
        let mut t = sample_task(id, TaskStatus::Running);
        t.ai_cli_kind = kind;
        db.insert_task(&t).unwrap();
        assert_eq!(db.get_task(id).unwrap().unwrap().ai_cli_kind, kind);
    }
}

#[test]
fn task_status_round_trip_all_variants() {
    let db = Database::in_memory().unwrap();
    for (status, id) in [
        (TaskStatus::Pending, "p"),
        (TaskStatus::PendingConfirmation, "pc"),
        (TaskStatus::Running, "r"),
        (TaskStatus::Succeeded, "s"),
        (TaskStatus::Failed, "f"),
        (TaskStatus::Cancelled, "c"),
    ] {
        db.insert_task(&sample_task(id, status)).unwrap();
        assert_eq!(db.get_task(id).unwrap().unwrap().status, status);
    }
}
