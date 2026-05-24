//! Supervisor tests — spawn real bash subprocesses (generic AiCliKind)
//! and verify lifecycle events propagate through the event bus.

#[path = "../src/auth.rs"]
#[allow(dead_code)]
mod auth;

#[path = "../src/db.rs"]
#[allow(dead_code)]
mod db;

#[path = "../src/error.rs"]
#[allow(dead_code)]
mod error;

#[path = "../src/event_bus.rs"]
#[allow(dead_code)]
mod event_bus;

#[path = "../src/event_log.rs"]
#[allow(dead_code)]
mod event_log;


#[path = "../src/handoff.rs"]
#[allow(dead_code)]
mod handoff;
#[path = "../src/handler.rs"]
#[allow(dead_code)]
mod handler;

#[path = "../src/server.rs"]
#[allow(dead_code)]
mod server;


#[path = "../src/cost_recorder.rs"]
#[allow(dead_code)]
mod cost_recorder;
#[path = "../src/supervisor.rs"]
#[allow(dead_code)]
mod supervisor;

#[path = "../src/mcp/mod.rs"]
#[allow(dead_code)]
mod mcp;

use std::sync::Arc;
use std::time::Duration;

use tokio::sync::Mutex;

use termex_core::daemon::ServerMessage;
use termex_core::task::{AiCliKind, TaskStatus};

use crate::db::Database;
use crate::event_bus::EventBus;
use crate::supervisor::{CancelKind, TaskSupervisor};

fn make_supervisor() -> (TaskSupervisor, Arc<Mutex<Database>>, EventBus) {
    let db = Arc::new(Mutex::new(Database::in_memory().unwrap()));
    let bus = EventBus::new();
    let sup = TaskSupervisor::new(db.clone(), bus.clone());
    (sup, db, bus)
}

#[tokio::test]
async fn spawn_simple_echo_emits_output_and_succeeded() {
    let (sup, db, bus) = make_supervisor();

    // Insert the task row first (mirrors what the handler does).
    let task_id = "t-echo".to_string();
    db.lock()
        .await
        .insert_task(&termex_core::task::Task {
            id: task_id.clone(),
            ai_cli_kind: AiCliKind::Generic,
            prompt: "echo hello".into(),
            workdir: None,
            status: TaskStatus::Running,
            started_at: "2026-05-23T00:00:00Z".into(),
            ended_at: None,
            exit_code: None,
            idle_timeout_sec: 30,
            output_tail: None,
            error: None,
        server_id: None,
        })
        .unwrap();

    let mut rx = bus.subscribe(&task_id).await;

    sup.spawn(&task_id, AiCliKind::Generic, "echo hello", None, None)
        .await
        .unwrap();

    let mut saw_output = false;
    let mut saw_terminal = false;
    let deadline = tokio::time::Instant::now() + Duration::from_secs(5);
    while tokio::time::Instant::now() < deadline && !saw_terminal {
        match tokio::time::timeout(Duration::from_millis(500), rx.recv()).await {
            Ok(Ok(ServerMessage::TaskOutput { data, .. })) => {
                if data.contains("hello") {
                    saw_output = true;
                }
            }
            Ok(Ok(ServerMessage::TaskStatus { status, exit_code, .. })) => {
                if status.is_terminal() {
                    assert_eq!(status, TaskStatus::Succeeded);
                    assert_eq!(exit_code, Some(0));
                    saw_terminal = true;
                }
            }
            Ok(Ok(_)) => continue,
            Ok(Err(_)) | Err(_) => continue,
        }
    }

    assert!(saw_output, "expected stdout chunk containing 'hello'");
    assert!(saw_terminal, "expected terminal TaskStatus");

    // Output tail persisted to DB
    let tail = db
        .lock()
        .await
        .get_task(&task_id)
        .unwrap()
        .unwrap()
        .output_tail
        .unwrap_or_default();
    assert!(tail.contains("hello"));
}

#[tokio::test]
async fn spawn_failing_command_emits_failed_status() {
    let (sup, db, bus) = make_supervisor();
    let task_id = "t-fail".to_string();
    db.lock()
        .await
        .insert_task(&termex_core::task::Task {
            id: task_id.clone(),
            ai_cli_kind: AiCliKind::Generic,
            prompt: "exit 7".into(),
            workdir: None,
            status: TaskStatus::Running,
            started_at: "2026-05-23T00:00:00Z".into(),
            ended_at: None,
            exit_code: None,
            idle_timeout_sec: 30,
            output_tail: None,
            error: None,
        server_id: None,
        })
        .unwrap();
    let mut rx = bus.subscribe(&task_id).await;

    sup.spawn(&task_id, AiCliKind::Generic, "exit 7", None, None)
        .await
        .unwrap();

    let deadline = tokio::time::Instant::now() + Duration::from_secs(5);
    let mut got = None;
    while tokio::time::Instant::now() < deadline {
        if let Ok(Ok(ServerMessage::TaskStatus { status, exit_code, .. })) =
            tokio::time::timeout(Duration::from_millis(500), rx.recv()).await
        {
            if status.is_terminal() {
                got = Some((status, exit_code));
                break;
            }
        }
    }
    let (status, exit_code) = got.expect("terminal status not received");
    assert_eq!(status, TaskStatus::Failed);
    assert_eq!(exit_code, Some(7));
}

#[tokio::test]
async fn active_count_increments_and_drops() {
    let (sup, db, _bus) = make_supervisor();
    let task_id = "t-active".to_string();
    db.lock()
        .await
        .insert_task(&termex_core::task::Task {
            id: task_id.clone(),
            ai_cli_kind: AiCliKind::Generic,
            prompt: "echo hi".into(),
            workdir: None,
            status: TaskStatus::Running,
            started_at: "2026-05-23T00:00:00Z".into(),
            ended_at: None,
            exit_code: None,
            idle_timeout_sec: 30,
            output_tail: None,
            error: None,
        server_id: None,
        })
        .unwrap();

    assert_eq!(sup.active_count().await, 0);
    sup.spawn(&task_id, AiCliKind::Generic, "echo hi", None, None)
        .await
        .unwrap();
    assert_eq!(sup.active_count().await, 1);

    // Wait for completion
    tokio::time::sleep(Duration::from_secs(2)).await;
    // Best-effort: waiter has had time to remove from active map
    assert_eq!(
        sup.active_count().await,
        0,
        "active count should drop after child exits"
    );
}

#[tokio::test]
async fn cancel_missing_task_returns_not_found() {
    let (sup, _db, _bus) = make_supervisor();
    let err = sup.cancel("does-not-exist", CancelKind::Sigint).await;
    assert!(err.is_err());
}

#[tokio::test]
async fn cancel_sigterm_terminates_long_running_task() {
    let (sup, db, bus) = make_supervisor();
    let task_id = "t-cancel".to_string();
    db.lock()
        .await
        .insert_task(&termex_core::task::Task {
            id: task_id.clone(),
            ai_cli_kind: AiCliKind::Generic,
            prompt: "sleep 60".into(),
            workdir: None,
            status: TaskStatus::Running,
            started_at: "2026-05-23T00:00:00Z".into(),
            ended_at: None,
            exit_code: None,
            idle_timeout_sec: 30,
            output_tail: None,
            error: None,
        server_id: None,
        })
        .unwrap();
    let mut rx = bus.subscribe(&task_id).await;

    sup.spawn(&task_id, AiCliKind::Generic, "sleep 60", None, None)
        .await
        .unwrap();
    tokio::time::sleep(Duration::from_millis(300)).await;
    sup.cancel(&task_id, CancelKind::Sigterm).await.unwrap();

    let deadline = tokio::time::Instant::now() + Duration::from_secs(5);
    let mut got_terminal = false;
    while tokio::time::Instant::now() < deadline && !got_terminal {
        if let Ok(Ok(ServerMessage::TaskStatus { status, .. })) =
            tokio::time::timeout(Duration::from_millis(500), rx.recv()).await
        {
            if status.is_terminal() {
                // Failed because sleep killed by signal — semantics
                // depend on shell, but it must be terminal.
                got_terminal = true;
                assert_ne!(status, TaskStatus::Succeeded);
            }
        }
    }
    assert!(got_terminal, "cancel should drive task to terminal state");
}
