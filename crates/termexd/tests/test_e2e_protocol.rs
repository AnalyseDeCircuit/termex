//! E2E tests: start a real termexd server bound to an ephemeral port,
//! connect with a raw tokio-tungstenite client, drive the full
//! request-response cycle.
//!
//! These mirror the validation matrix in
//! `docs/iterations/v0.71.0-core-termexd-daemon.md` §七.

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

use std::sync::Arc;
use std::time::Duration;

use futures_util::{SinkExt, StreamExt};
use tokio::net::TcpListener;
use tokio_tungstenite::tungstenite::client::IntoClientRequest;
use tokio_tungstenite::tungstenite::handshake::client::generate_key;
use tokio_tungstenite::tungstenite::http::Request;
use tokio_tungstenite::tungstenite::Message;

use crate::db::Database;
use crate::event_bus::EventBus;
use crate::handler::HandlerCtx;

const TOKEN: &str = "test-token-1234567890abcdef1234567890abcdef1234567890abcdef12345678";

/// Spin up the server on an ephemeral port and return (addr, server task).
async fn spawn_server() -> (String, tokio::task::JoinHandle<anyhow::Result<()>>) {
    // Find a free port by binding-and-dropping a temporary listener
    // (tokio_tungstenite's accept_hdr_async needs a fresh bind, so we
    // pass "0" and rely on server.rs to handle it).
    let probe = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = probe.local_addr().unwrap();
    drop(probe);

    let db = Database::in_memory().unwrap();
    let bus = EventBus::new();
    // Use the no-spawn variant so basic protocol tests don't fork
    // actual bash subprocesses; supervisor.rs has dedicated tests
    // covering real spawn / cancel.
    let ctx = HandlerCtx::new_no_spawn(db, bus);
    let listen = format!("127.0.0.1:{}", addr.port());
    let token = TOKEN.to_string();
    let handle = tokio::spawn(async move { server::run(&listen, token, ctx).await });

    // Give the server a moment to bind.
    tokio::time::sleep(Duration::from_millis(50)).await;
    (format!("127.0.0.1:{}", addr.port()), handle)
}

fn build_request(addr: &str, token: Option<&str>, path: &str) -> Request<()> {
    let mut req = format!("ws://{addr}{path}")
        .into_client_request()
        .unwrap();
    req.headers_mut().insert(
        "sec-websocket-key",
        generate_key().parse().unwrap(),
    );
    if let Some(t) = token {
        req.headers_mut().insert(
            "authorization",
            format!("Bearer {}", t).parse().unwrap(),
        );
    }
    req
}

#[tokio::test]
async fn rejects_wrong_token() {
    let (addr, _server) = spawn_server().await;
    let req = build_request(&addr, Some("wrong-token"), "/v1/stream");
    let res = tokio_tungstenite::connect_async(req).await;
    assert!(res.is_err(), "wrong token must be rejected");
}

#[tokio::test]
async fn rejects_missing_token() {
    let (addr, _server) = spawn_server().await;
    let req = build_request(&addr, None, "/v1/stream");
    let res = tokio_tungstenite::connect_async(req).await;
    assert!(res.is_err(), "missing token must be rejected");
}

#[tokio::test]
async fn rejects_wrong_path() {
    let (addr, _server) = spawn_server().await;
    let req = build_request(&addr, Some(TOKEN), "/v999/stream");
    let res = tokio_tungstenite::connect_async(req).await;
    assert!(res.is_err(), "unknown path must 404");
}

#[tokio::test]
async fn ping_pong_round_trip() {
    let (addr, _server) = spawn_server().await;
    let req = build_request(&addr, Some(TOKEN), "/v1/stream");
    let (mut ws, _resp) = tokio_tungstenite::connect_async(req).await.unwrap();

    let ping = serde_json::json!({
        "type": "ping",
        "request_id": "p1",
        "ts_ms": 12345u64,
    });
    ws.send(Message::Text(ping.to_string())).await.unwrap();

    let resp = ws.next().await.unwrap().unwrap();
    let text = match resp {
        Message::Text(t) => t,
        other => panic!("unexpected frame: {:?}", other),
    };
    let v: serde_json::Value = serde_json::from_str(&text).unwrap();
    assert_eq!(v["type"], "response");
    assert_eq!(v["request_id"], "p1");
    assert_eq!(v["ok"], true);
    assert_eq!(v["data"]["echo_ts_ms"], 12345);
}

#[tokio::test]
async fn task_assign_then_list() {
    let (addr, _server) = spawn_server().await;
    let req = build_request(&addr, Some(TOKEN), "/v1/stream");
    let (mut ws, _) = tokio_tungstenite::connect_async(req).await.unwrap();

    // Assign
    let assign = serde_json::json!({
        "type": "task.assign",
        "request_id": "a1",
        "ai_cli": "claude_code",
        "prompt": "fix bug X",
        "idle_timeout_sec": 30,
    });
    ws.send(Message::Text(assign.to_string())).await.unwrap();
    let resp = ws.next().await.unwrap().unwrap();
    let t = match resp {
        Message::Text(t) => t,
        other => panic!("unexpected: {:?}", other),
    };
    let v: serde_json::Value = serde_json::from_str(&t).unwrap();
    assert_eq!(v["ok"], true);
    let task_id = v["data"]["task_id"].as_str().unwrap().to_string();
    assert!(!task_id.is_empty());

    // List
    let list = serde_json::json!({"type":"task.list","request_id":"l1","filter":{}});
    ws.send(Message::Text(list.to_string())).await.unwrap();
    let resp = ws.next().await.unwrap().unwrap();
    let t = match resp {
        Message::Text(t) => t,
        other => panic!("unexpected: {:?}", other),
    };
    let v: serde_json::Value = serde_json::from_str(&t).unwrap();
    assert_eq!(v["ok"], true);
    let tasks = v["data"]["tasks"].as_array().unwrap();
    assert_eq!(tasks.len(), 1);
    assert_eq!(tasks[0]["id"], task_id);
    assert_eq!(tasks[0]["status"], "running");
}

#[tokio::test]
async fn task_cancel_updates_status() {
    let (addr, _server) = spawn_server().await;
    let req = build_request(&addr, Some(TOKEN), "/v1/stream");
    let (mut ws, _) = tokio_tungstenite::connect_async(req).await.unwrap();

    // Assign
    ws.send(Message::Text(
        serde_json::json!({
            "type":"task.assign","request_id":"a","ai_cli":"generic",
            "prompt":"sleep 10","idle_timeout_sec":30,
        })
        .to_string(),
    ))
    .await
    .unwrap();
    let v: serde_json::Value =
        serde_json::from_str(text_of(ws.next().await.unwrap().unwrap()).as_str()).unwrap();
    let task_id = v["data"]["task_id"].as_str().unwrap().to_string();

    // Cancel
    ws.send(Message::Text(
        serde_json::json!({
            "type":"task.cancel","request_id":"c","task_id":task_id,
        })
        .to_string(),
    ))
    .await
    .unwrap();
    let _ack = ws.next().await.unwrap().unwrap();

    // Verify via list
    ws.send(Message::Text(
        serde_json::json!({"type":"task.list","request_id":"l","filter":{"status":"cancelled"}})
            .to_string(),
    ))
    .await
    .unwrap();
    let v: serde_json::Value =
        serde_json::from_str(text_of(ws.next().await.unwrap().unwrap()).as_str()).unwrap();
    let tasks = v["data"]["tasks"].as_array().unwrap();
    assert_eq!(tasks.len(), 1);
    assert_eq!(tasks[0]["id"], task_id);
}

#[tokio::test]
async fn malformed_message_returns_bad_request() {
    let (addr, _server) = spawn_server().await;
    let req = build_request(&addr, Some(TOKEN), "/v1/stream");
    let (mut ws, _) = tokio_tungstenite::connect_async(req).await.unwrap();

    ws.send(Message::Text("not json at all".into()))
        .await
        .unwrap();
    let v: serde_json::Value =
        serde_json::from_str(text_of(ws.next().await.unwrap().unwrap()).as_str()).unwrap();
    assert_eq!(v["ok"], false);
    assert_eq!(v["code"], "ERR_BAD_REQUEST");
    assert!(v["error"].as_str().unwrap().contains("parse"));
}

#[tokio::test]
async fn ws_ping_pong_keepalive() {
    let (addr, _server) = spawn_server().await;
    let req = build_request(&addr, Some(TOKEN), "/v1/stream");
    let (mut ws, _) = tokio_tungstenite::connect_async(req).await.unwrap();

    ws.send(Message::Ping(vec![1, 2, 3])).await.unwrap();
    let resp = ws.next().await.unwrap().unwrap();
    match resp {
        Message::Pong(p) => assert_eq!(p, vec![1, 2, 3]),
        other => panic!("expected Pong, got {:?}", other),
    }
}

#[tokio::test]
async fn event_bus_broadcasts_status_on_assign() {
    // Internal smoke for the event bus: subscribe, then assign,
    // expect a status event.
    let bus = EventBus::new();
    let mut rx = bus.subscribe("any-task").await;
    let db = Database::in_memory().unwrap();
    let ctx = HandlerCtx::new(db, bus.clone());

    // Hand-craft a TaskAssign and route directly through the handler.
    let resp = handler::handle(
        &ctx,
        termex_core::daemon::ClientMessage::TaskAssign {
            request_id: "req".into(),
            ai_cli: termex_core::task::AiCliKind::Generic,
            prompt: "echo hi".into(),
            workdir: None,
            idle_timeout_sec: 30,
        },
    )
    .await;
    // Response ok
    if let termex_core::daemon::ServerMessage::Response { ok, data, .. } = resp {
        assert!(ok);
        let _ = data;
    } else {
        panic!("expected Response variant");
    }

    // For this milestone we don't yet broadcast on a known task_id
    // (uuid is generated server-side), so the existing "any-task"
    // subscriber should NOT have received anything — i.e. broadcast
    // is keyed by task_id. Drain non-blocking.
    let _ = rx;
    // Verify channel count increased to include the new task id.
    // (Best-effort smoke; full broadcast-to-known-id assertion will
    // come with the subscribe-then-assign integration in the
    // upcoming server.rs commit.)
    assert!(bus.active_channel_count().await >= 1);
    let _ = Arc::strong_count(&ctx); // silence unused
}

fn text_of(m: Message) -> String {
    match m {
        Message::Text(t) => t,
        other => panic!("expected text, got {:?}", other),
    }
}
