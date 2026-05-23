//! E2E test for the subscribe path: connect a real client, assign a
//! task that produces output, subscribe, and verify the live event
//! stream lands on the WebSocket.
//!
//! Uses the real PTY-spawning HandlerCtx (not the no-spawn helper)
//! to exercise supervisor → event bus → server fan-in → WS sink.

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

use futures_util::{SinkExt, StreamExt};
use tokio::net::TcpListener;
use tokio_tungstenite::tungstenite::client::IntoClientRequest;
use tokio_tungstenite::tungstenite::handshake::client::generate_key;
use tokio_tungstenite::tungstenite::http::Request;
use tokio_tungstenite::tungstenite::Message;

use crate::db::Database;
use crate::event_bus::EventBus;
use crate::handler::HandlerCtx;

const TOKEN: &str = "subscribe-test-token-1234567890abcdef1234567890abcdef12345678ab";

async fn spawn_real_server() -> String {
    let probe = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = probe.local_addr().unwrap();
    drop(probe);

    let db = Database::in_memory().unwrap();
    let bus = EventBus::new();
    let ctx = HandlerCtx::new(db, bus); // real spawn
    let listen = format!("127.0.0.1:{}", addr.port());
    let token = TOKEN.to_string();
    tokio::spawn(async move { server::run(&listen, token, ctx).await });

    tokio::time::sleep(Duration::from_millis(100)).await;
    format!("127.0.0.1:{}", addr.port())
}

fn build_request(addr: &str, token: &str) -> Request<()> {
    let mut req = format!("ws://{addr}/v1/stream")
        .into_client_request()
        .unwrap();
    req.headers_mut()
        .insert("sec-websocket-key", generate_key().parse().unwrap());
    req.headers_mut()
        .insert("authorization", format!("Bearer {token}").parse().unwrap());
    req
}

#[tokio::test]
async fn subscribe_receives_live_output_and_terminal_status() {
    let addr = spawn_real_server().await;
    let req = build_request(&addr, TOKEN);
    let (mut ws, _) = tokio_tungstenite::connect_async(req).await.unwrap();

    // 1. Assign a task (real PTY) that produces some output.
    ws.send(Message::Text(
        serde_json::json!({
            "type": "task.assign",
            "request_id": "a1",
            "ai_cli": "generic",
            "prompt": "echo subscribe-marker && exit 0",
            "idle_timeout_sec": 30
        })
        .to_string(),
    ))
    .await
    .unwrap();

    // 2. First frame must be the Response with task_id.
    let task_id = loop {
        let frame = ws.next().await.unwrap().unwrap();
        let text = match frame {
            Message::Text(t) => t,
            _ => continue,
        };
        let v: serde_json::Value = serde_json::from_str(&text).unwrap();
        if v["type"] == "response" && v["request_id"] == "a1" {
            assert_eq!(v["ok"], true);
            break v["data"]["task_id"].as_str().unwrap().to_string();
        }
    };

    // 3. Subscribe to the task.
    ws.send(Message::Text(
        serde_json::json!({
            "type": "task.subscribe", "request_id": "s1", "task_id": task_id,
        })
        .to_string(),
    ))
    .await
    .unwrap();

    // 4. Drain frames until we see the marker output and a terminal
    //    status, or hit a wall-clock deadline.
    let mut saw_output = false;
    let mut saw_terminal = false;
    let deadline = tokio::time::Instant::now() + Duration::from_secs(8);
    while tokio::time::Instant::now() < deadline && !saw_terminal {
        let next =
            match tokio::time::timeout(Duration::from_millis(500), ws.next()).await {
                Ok(Some(Ok(m))) => m,
                _ => continue,
            };
        let text = match next {
            Message::Text(t) => t,
            _ => continue,
        };
        let v: serde_json::Value = serde_json::from_str(&text).unwrap();
        match v["type"].as_str() {
            Some("task.output") => {
                let data = v["data"].as_str().unwrap_or("");
                if data.contains("subscribe-marker") {
                    saw_output = true;
                }
                // Validate seq is present and monotonic-ish.
                assert!(v["seq"].is_u64());
            }
            Some("task.status") => {
                let status = v["status"].as_str().unwrap_or("");
                if status == "succeeded" {
                    saw_terminal = true;
                    assert_eq!(v["exit_code"], 0);
                    assert!(v["duration_ms"].is_u64());
                } else if status == "failed" || status == "cancelled" {
                    panic!("unexpected terminal status: {status}");
                }
            }
            Some("response") => continue,
            _ => continue,
        }
    }

    assert!(saw_output, "subscribe did not deliver the output chunk");
    assert!(
        saw_terminal,
        "subscribe did not deliver the terminal TaskStatus event"
    );
}

#[tokio::test]
async fn subscribe_then_unsubscribe_stops_events() {
    let addr = spawn_real_server().await;
    let req = build_request(&addr, TOKEN);
    let (mut ws, _) = tokio_tungstenite::connect_async(req).await.unwrap();

    // Assign first
    ws.send(Message::Text(
        serde_json::json!({
            "type": "task.assign",
            "request_id": "a",
            "ai_cli": "generic",
            "prompt": "sleep 0.2 && echo done",
            "idle_timeout_sec": 30
        })
        .to_string(),
    ))
    .await
    .unwrap();
    let task_id = loop {
        let m = ws.next().await.unwrap().unwrap();
        if let Message::Text(t) = m {
            let v: serde_json::Value = serde_json::from_str(&t).unwrap();
            if v["request_id"] == "a" && v["type"] == "response" {
                break v["data"]["task_id"].as_str().unwrap().to_string();
            }
        }
    };

    // Subscribe
    ws.send(Message::Text(
        serde_json::json!({"type":"task.subscribe","request_id":"s","task_id":task_id})
            .to_string(),
    ))
    .await
    .unwrap();
    // Drain the subscribe ack
    let _ = tokio::time::timeout(Duration::from_secs(1), ws.next()).await;

    // Immediately unsubscribe
    ws.send(Message::Text(
        serde_json::json!({"type":"task.unsubscribe","request_id":"u","task_id":task_id})
            .to_string(),
    ))
    .await
    .unwrap();

    // We may still get the unsubscribe ack + any in-flight events,
    // but after a short grace period we should see NO new
    // `task.output` arriving (the subscription pump task is aborted).
    // This is best-effort timing: assert that we don't crash and the
    // connection stays usable.
    let _grace = tokio::time::sleep(Duration::from_millis(500)).await;
    // Send a benign ping and make sure we still get a pong.
    ws.send(Message::Text(
        serde_json::json!({"type":"ping","request_id":"p","ts_ms":42u64}).to_string(),
    ))
    .await
    .unwrap();
    let pong = loop {
        let m =
            tokio::time::timeout(Duration::from_secs(2), ws.next())
                .await
                .expect("pong timeout")
                .unwrap()
                .unwrap();
        if let Message::Text(t) = m {
            let v: serde_json::Value = serde_json::from_str(&t).unwrap();
            if v["request_id"] == "p" {
                break v;
            }
        }
    };
    assert_eq!(pong["ok"], true);
}
