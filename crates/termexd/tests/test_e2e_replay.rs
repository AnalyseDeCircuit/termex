//! E2E test for stream.replay — full DaemonClient ⇄ termexd round
//! trip through real WebSocket + event log + replay.

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

#[path = "../src/supervisor.rs"]
#[allow(dead_code)]
mod supervisor;

#[path = "../src/mcp/mod.rs"]
#[allow(dead_code)]
mod mcp;

use std::time::Duration;

use tokio::net::TcpListener;

use termex_core::daemon::{AssignRequest, DaemonClient, ServerMessage};
use termex_core::task::{AiCliKind, TaskStatus};

use crate::db::Database;
use crate::event_bus::EventBus;
use crate::handler::HandlerCtx;

const TOKEN: &str = "replay-test-tok-1234567890abcdef1234567890abcdef1234567890abcdef";

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
async fn stream_replay_returns_zero_when_nothing_to_replay() {
    let url = spawn_server(false).await;
    let client = DaemonClient::connect(&url, TOKEN).await.unwrap();
    let n = client.stream_replay(u64::MAX, 100).await.unwrap();
    assert_eq!(n, 0);
}

#[tokio::test]
async fn stream_replay_backfills_recorded_status_events() {
    let url = spawn_server(false).await;
    let client = DaemonClient::connect(&url, TOKEN).await.unwrap();

    // Generate two task.status events via assigns (no_spawn path —
    // each assign broadcasts a TaskStatus with monotonic seq).
    for i in 0..3 {
        client
            .task_assign(AssignRequest {
                ai_cli: AiCliKind::Generic,
                prompt: format!("p-{i}"),
                ..Default::default()
            })
            .await
            .unwrap();
    }

    let n = client.stream_replay(0, 100).await.unwrap();
    assert!(n >= 3, "expected ≥3 status events; got {n}");
}

#[tokio::test]
async fn stream_replay_with_real_pty_includes_output_and_terminal() {
    let url = spawn_server(true).await;
    let client = DaemonClient::connect(&url, TOKEN).await.unwrap();

    let task_id = client
        .task_assign(AssignRequest {
            ai_cli: AiCliKind::Generic,
            prompt: "echo replay-marker && exit 0".into(),
            workdir: None,
            idle_timeout_sec: 30,
        })
        .await
        .unwrap();

    // Give the supervisor enough time to spawn + run + reap.
    tokio::time::sleep(Duration::from_secs(2)).await;

    // Subscribe AFTER the task already finished; without replay we'd
    // see nothing. With replay we should see the recorded events.
    let mut rx = client.subscribe(&task_id).await.unwrap();
    let n = client.stream_replay(0, 100).await.unwrap();
    assert!(n > 0, "expected events to replay; got {n}");

    let mut saw_marker = false;
    let mut saw_terminal = false;
    let deadline = tokio::time::Instant::now() + Duration::from_secs(3);
    while tokio::time::Instant::now() < deadline && !saw_terminal {
        match tokio::time::timeout(Duration::from_millis(300), rx.recv()).await {
            Ok(Ok(ServerMessage::TaskOutput { data, .. })) => {
                if data.contains("replay-marker") {
                    saw_marker = true;
                }
            }
            Ok(Ok(ServerMessage::TaskStatus { status, .. })) if status.is_terminal() => {
                assert_eq!(status, TaskStatus::Succeeded);
                saw_terminal = true;
            }
            _ => continue,
        }
    }
    assert!(saw_marker, "replay should re-emit output");
    assert!(saw_terminal, "replay should re-emit terminal status");
}
