//! DaemonClient SDK ⇄ real termexd integration tests.
//!
//! Spins up a real termexd WS server on an ephemeral port, connects
//! a DaemonClient to it, exercises every public method.

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

#[path = "../src/handler.rs"]
#[allow(dead_code)]
mod handler;

#[path = "../src/server.rs"]
#[allow(dead_code)]
mod server;

#[path = "../src/supervisor.rs"]
#[allow(dead_code)]
mod supervisor;

#[path = "../src/mcp/mod.rs"]
#[allow(dead_code)]
mod mcp;

use std::time::Duration;

use tokio::net::TcpListener;

use termex_core::daemon::{
    AssignRequest, CancelSignal, ClientError, DaemonClient, ServerMessage, TaskFilter,
};
use termex_core::task::{AiCliKind, TaskStatus};

use crate::db::Database;
use crate::event_bus::EventBus;
use crate::handler::HandlerCtx;

const TOKEN: &str = "client-test-tok-1234567890abcdef1234567890abcdef1234567890abcdef";

/// Spin up a real termexd server. `real_spawn=true` uses the actual
/// PTY supervisor; `false` uses the no-spawn variant for protocol-
/// only checks.
async fn spawn_server(real_spawn: bool) -> String {
    let probe = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = probe.local_addr().unwrap().port();
    drop(probe);

    let db = Database::in_memory().unwrap();
    let bus = EventBus::new();
    let ctx = if real_spawn {
        HandlerCtx::new(db, bus)
    } else {
        HandlerCtx::new_no_spawn(db, bus)
    };
    let listen = format!("127.0.0.1:{port}");
    let token = TOKEN.to_string();
    tokio::spawn(async move { server::run(&listen, token, ctx).await });
    tokio::time::sleep(Duration::from_millis(100)).await;
    format!("ws://127.0.0.1:{port}/v1/stream")
}

#[tokio::test]
async fn connect_with_bad_token_returns_connect_error() {
    let url = spawn_server(false).await;
    let res = DaemonClient::connect(&url, "wrong-token").await;
    assert!(matches!(res, Err(ClientError::Connect(_))));
}

#[tokio::test]
async fn connect_with_good_token_succeeds() {
    let url = spawn_server(false).await;
    let client = DaemonClient::connect(&url, TOKEN).await.unwrap();
    client.close().await.unwrap();
}

#[tokio::test]
async fn task_assign_returns_task_id() {
    let url = spawn_server(false).await;
    let client = DaemonClient::connect(&url, TOKEN).await.unwrap();

    let task_id = client
        .task_assign(AssignRequest {
            ai_cli: AiCliKind::Generic,
            prompt: "noop".into(),
            workdir: None,
            idle_timeout_sec: 30,
        })
        .await
        .unwrap();
    assert!(!task_id.is_empty(), "expected non-empty task id");
}

#[tokio::test]
async fn task_list_returns_assigned_tasks() {
    let url = spawn_server(false).await;
    let client = DaemonClient::connect(&url, TOKEN).await.unwrap();

    let id1 = client
        .task_assign(AssignRequest {
            ai_cli: AiCliKind::ClaudeCode,
            prompt: "p1".into(),
            ..Default::default()
        })
        .await
        .unwrap();
    let id2 = client
        .task_assign(AssignRequest {
            ai_cli: AiCliKind::Codex,
            prompt: "p2".into(),
            ..Default::default()
        })
        .await
        .unwrap();

    let all = client.task_list(TaskFilter::default()).await.unwrap();
    let ids: Vec<&str> = all.iter().map(|t| t.id.as_str()).collect();
    assert!(ids.contains(&id1.as_str()));
    assert!(ids.contains(&id2.as_str()));
    assert_eq!(all.len(), 2);
}

#[tokio::test]
async fn task_list_with_status_filter() {
    let url = spawn_server(false).await;
    let client = DaemonClient::connect(&url, TOKEN).await.unwrap();

    let _ = client
        .task_assign(AssignRequest {
            ai_cli: AiCliKind::Generic,
            prompt: "x".into(),
            ..Default::default()
        })
        .await
        .unwrap();

    let running = client
        .task_list(TaskFilter {
            status: Some(TaskStatus::Running),
        })
        .await
        .unwrap();
    assert_eq!(running.len(), 1);
    assert_eq!(running[0].status, TaskStatus::Running);

    let succeeded = client
        .task_list(TaskFilter {
            status: Some(TaskStatus::Succeeded),
        })
        .await
        .unwrap();
    assert_eq!(succeeded.len(), 0);
}

#[tokio::test]
async fn task_get_returns_task_or_none() {
    let url = spawn_server(false).await;
    let client = DaemonClient::connect(&url, TOKEN).await.unwrap();

    let task_id = client
        .task_assign(AssignRequest {
            ai_cli: AiCliKind::Aider,
            prompt: "p".into(),
            ..Default::default()
        })
        .await
        .unwrap();

    let got = client.task_get(&task_id).await.unwrap();
    assert!(got.is_some());
    assert_eq!(got.unwrap().id, task_id);

    let missing = client.task_get("does-not-exist-uuid").await.unwrap();
    assert!(missing.is_none());
}

#[tokio::test]
async fn task_cancel_db_only_fallback() {
    let url = spawn_server(false).await;
    let client = DaemonClient::connect(&url, TOKEN).await.unwrap();

    let task_id = client
        .task_assign(AssignRequest {
            ai_cli: AiCliKind::Generic,
            prompt: "ignored".into(),
            ..Default::default()
        })
        .await
        .unwrap();

    // No PTY ran (spawn_disabled), so cancel goes through the
    // handler's TaskNotFound fallback → DB-only status flip.
    client
        .task_cancel(&task_id, CancelSignal::Sigint)
        .await
        .unwrap();

    let after = client.task_get(&task_id).await.unwrap().unwrap();
    assert_eq!(after.status, TaskStatus::Cancelled);
}

#[tokio::test]
async fn subscribe_receives_live_output_with_real_pty() {
    let url = spawn_server(true).await; // real spawn
    let client = DaemonClient::connect(&url, TOKEN).await.unwrap();

    let task_id = client
        .task_assign(AssignRequest {
            ai_cli: AiCliKind::Generic,
            prompt: "echo daemonclient-marker && exit 0".into(),
            workdir: None,
            idle_timeout_sec: 30,
        })
        .await
        .unwrap();

    let mut rx = client.subscribe(&task_id).await.unwrap();

    let mut saw_output = false;
    let mut saw_terminal = false;
    let deadline = tokio::time::Instant::now() + Duration::from_secs(8);
    while tokio::time::Instant::now() < deadline && !saw_terminal {
        match tokio::time::timeout(Duration::from_millis(500), rx.recv()).await {
            Ok(Ok(msg)) => match msg {
                ServerMessage::TaskOutput { data, .. } => {
                    if data.contains("daemonclient-marker") {
                        saw_output = true;
                    }
                }
                ServerMessage::TaskStatus {
                    status, exit_code, ..
                } => {
                    if status.is_terminal() {
                        assert_eq!(status, TaskStatus::Succeeded);
                        assert_eq!(exit_code, Some(0));
                        saw_terminal = true;
                    }
                }
                _ => {}
            },
            _ => continue,
        }
    }
    assert!(saw_output, "subscribe did not deliver the output chunk");
    assert!(saw_terminal, "subscribe did not deliver terminal status");
}

#[tokio::test]
async fn many_concurrent_requests_correlate_by_request_id() {
    let url = spawn_server(false).await;
    let client = DaemonClient::connect(&url, TOKEN).await.unwrap();

    // Fire 20 concurrent assigns; each should resolve with its own
    // unique task_id without crossed wires.
    let mut handles = tokio::task::JoinSet::new();
    for i in 0..20u32 {
        let c = client.clone();
        handles.spawn(async move {
            c.task_assign(AssignRequest {
                ai_cli: AiCliKind::Generic,
                prompt: format!("p-{i}"),
                ..Default::default()
            })
            .await
        });
    }

    let mut ids = std::collections::HashSet::new();
    while let Some(joined) = handles.join_next().await {
        let id = joined
            .expect("task did not panic")
            .expect("each assign should succeed");
        assert!(ids.insert(id), "request_id correlation crossed wires");
    }
    assert_eq!(ids.len(), 20);
}

#[tokio::test]
async fn close_drops_connection_cleanly() {
    let url = spawn_server(false).await;
    let client = DaemonClient::connect(&url, TOKEN).await.unwrap();
    client.close().await.unwrap();
}
