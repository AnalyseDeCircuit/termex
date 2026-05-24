//! Bridge `api/daemon.rs` integration tests — spawn a mock termexd
//! WS server, exercise the FRB-level functions end to end.
//!
//! These tests stand up an actual `tokio_tungstenite` server that
//! speaks the v0.71.0 wire protocol (auth + Response routing for
//! task.assign / list / get / cancel) and verify the bridge layer
//! correctly maps results into the FRB DTOs / error-string format.

use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;

use futures_util::{SinkExt, StreamExt};
use tokio::net::TcpListener;
use tokio::sync::Mutex;
use tokio_tungstenite::tungstenite::handshake::server::{ErrorResponse, Request, Response};
use tokio_tungstenite::tungstenite::http::StatusCode;
use tokio_tungstenite::tungstenite::Message;

use termex_flutter_bridge::api::daemon;

const TOKEN: &str = "bridge-test-tok-abcdef1234567890abcdef1234567890abcdef1234567890ab";

/// Stand up a stripped-down WS server that mirrors termexd's
/// protocol surface enough for the bridge to drive it.
async fn spawn_mock_daemon() -> String {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = listener.local_addr().unwrap().port();
    let url = format!("ws://127.0.0.1:{port}/v1/stream");

    tokio::spawn(async move {
        loop {
            let (stream, _) = match listener.accept().await {
                Ok(v) => v,
                Err(_) => break,
            };
            tokio::spawn(handle_mock_conn(stream));
        }
    });
    tokio::time::sleep(Duration::from_millis(80)).await;
    url
}

async fn handle_mock_conn(stream: tokio::net::TcpStream) {
    let mut auth_ok = false;
    let ws = match tokio_tungstenite::accept_hdr_async(stream, |req: &Request, resp: Response| {
        if let Some(authz) = req.headers().get("authorization") {
            if let Ok(s) = authz.to_str() {
                if s.strip_prefix("Bearer ") == Some(TOKEN) {
                    auth_ok = true;
                }
            }
        }
        if !auth_ok {
            let mut r = ErrorResponse::new(None);
            *r.status_mut() = StatusCode::UNAUTHORIZED;
            return Err(r);
        }
        Ok(resp)
    })
    .await
    {
        Ok(w) => w,
        Err(_) => return,
    };

    let (mut sink, mut source) = ws.split();
    let tasks: Arc<Mutex<HashMap<String, serde_json::Value>>> =
        Arc::new(Mutex::new(HashMap::new()));

    while let Some(Ok(msg)) = source.next().await {
        let Message::Text(text) = msg else {
            continue;
        };
        let parsed: serde_json::Value = match serde_json::from_str(&text) {
            Ok(v) => v,
            Err(_) => continue,
        };
        let request_id = parsed["request_id"].as_str().unwrap_or("?").to_string();
        let type_ = parsed["type"].as_str().unwrap_or("?");

        let response = match type_ {
            "task.assign" => {
                let task_id = format!("mock-task-{}", tasks.lock().await.len() + 1);
                let row = serde_json::json!({
                    "id": task_id,
                    "ai_cli_kind": parsed["ai_cli"].clone(),
                    "prompt": parsed["prompt"].clone(),
                    "workdir": parsed.get("workdir").cloned().unwrap_or(serde_json::Value::Null),
                    "status": "running",
                    "started_at": "2026-05-23T00:00:00Z",
                    "ended_at": null,
                    "exit_code": null,
                    "idle_timeout_sec": parsed["idle_timeout_sec"].as_u64().unwrap_or(30),
                    "output_tail": null,
                    "error": null,
                });
                tasks.lock().await.insert(task_id.clone(), row);
                serde_json::json!({
                    "type": "response", "request_id": request_id,
                    "ok": true, "data": { "task_id": task_id }
                })
            }
            "task.list" => {
                let want_status = parsed["filter"]["status"].as_str();
                let all: Vec<_> = tasks
                    .lock()
                    .await
                    .values()
                    .filter(|t| {
                        want_status
                            .map(|s| t["status"].as_str() == Some(s))
                            .unwrap_or(true)
                    })
                    .cloned()
                    .collect();
                serde_json::json!({
                    "type": "response", "request_id": request_id,
                    "ok": true, "data": { "tasks": all }
                })
            }
            "task.get" => {
                let id = parsed["task_id"].as_str().unwrap_or("");
                let task = tasks.lock().await.get(id).cloned();
                serde_json::json!({
                    "type": "response", "request_id": request_id,
                    "ok": true, "data": { "task": task }
                })
            }
            "task.cancel" => {
                let id = parsed["task_id"].as_str().unwrap_or("").to_string();
                if let Some(t) = tasks.lock().await.get_mut(&id) {
                    t["status"] = serde_json::Value::String("cancelled".into());
                }
                serde_json::json!({
                    "type": "response", "request_id": request_id,
                    "ok": true, "data": null
                })
            }
            "task.subscribe" | "task.unsubscribe" | "task.decide" => serde_json::json!({
                "type": "response", "request_id": request_id, "ok": true, "data": null
            }),
            "ping" => serde_json::json!({
                "type": "response", "request_id": request_id,
                "ok": true, "data": { "echo_ts_ms": parsed["ts_ms"].as_u64().unwrap_or(0) }
            }),
            _ => serde_json::json!({
                "type": "response", "request_id": request_id,
                "ok": false, "code": "ERR_BAD_REQUEST",
                "error": format!("unknown type {type_}")
            }),
        };
        let _ = sink.send(Message::Text(response.to_string())).await;
    }
}

#[tokio::test]
async fn daemon_connect_rejects_bad_token() {
    let url = spawn_mock_daemon().await;
    let res = daemon::daemon_connect(url, "wrong".into()).await;
    assert!(res.is_err());
    assert!(res.unwrap_err().starts_with("ERR_WS"));
}

#[tokio::test]
async fn daemon_connect_succeeds_and_returns_handle() {
    let url = spawn_mock_daemon().await;
    let handle = daemon::daemon_connect(url, TOKEN.into()).await.unwrap();
    assert!(handle.starts_with("daemon-"));
    daemon::daemon_disconnect(handle).await.unwrap();
}

#[tokio::test]
async fn daemon_task_assign_round_trip() {
    let url = spawn_mock_daemon().await;
    let handle = daemon::daemon_connect(url, TOKEN.into()).await.unwrap();
    let task_id = daemon::daemon_task_assign(
        handle.clone(),
        daemon::AiCliKindDto::ClaudeCode,
        "fix bug".into(),
        Some("/repo".into()),
        30,
        None,
    )
    .await
    .unwrap();
    assert_eq!(task_id, "mock-task-1");

    let listing = daemon::daemon_task_list(handle.clone(), None).await.unwrap();
    assert_eq!(listing.len(), 1);
    assert_eq!(listing[0].id, task_id);
    assert_eq!(listing[0].prompt, "fix bug");
    assert!(matches!(
        listing[0].ai_cli_kind,
        daemon::AiCliKindDto::ClaudeCode
    ));
    assert!(matches!(listing[0].status, daemon::TaskStatusDto::Running));

    let got = daemon::daemon_task_get(handle.clone(), task_id.clone())
        .await
        .unwrap();
    assert!(got.is_some());

    let missing = daemon::daemon_task_get(handle.clone(), "nope".into())
        .await
        .unwrap();
    assert!(missing.is_none());

    daemon::daemon_disconnect(handle).await.unwrap();
}

#[tokio::test]
async fn daemon_task_list_with_status_filter_round_trips() {
    let url = spawn_mock_daemon().await;
    let handle = daemon::daemon_connect(url, TOKEN.into()).await.unwrap();
    let _ = daemon::daemon_task_assign(
        handle.clone(),
        daemon::AiCliKindDto::Generic,
        "x".into(),
        None,
        30,
        None,
    )
    .await
    .unwrap();

    let running = daemon::daemon_task_list(
        handle.clone(),
        Some(daemon::TaskStatusDto::Running),
    )
    .await
    .unwrap();
    assert_eq!(running.len(), 1);

    let succeeded = daemon::daemon_task_list(
        handle.clone(),
        Some(daemon::TaskStatusDto::Succeeded),
    )
    .await
    .unwrap();
    assert!(succeeded.is_empty());

    daemon::daemon_disconnect(handle).await.unwrap();
}

#[tokio::test]
async fn daemon_task_cancel_flips_status() {
    let url = spawn_mock_daemon().await;
    let handle = daemon::daemon_connect(url, TOKEN.into()).await.unwrap();
    let task_id = daemon::daemon_task_assign(
        handle.clone(),
        daemon::AiCliKindDto::Generic,
        "sleep".into(),
        None,
        30,
        None,
    )
    .await
    .unwrap();

    daemon::daemon_task_cancel(handle.clone(), task_id.clone(), "sigterm".into())
        .await
        .unwrap();

    let after = daemon::daemon_task_get(handle.clone(), task_id.clone())
        .await
        .unwrap()
        .unwrap();
    assert!(matches!(after.status, daemon::TaskStatusDto::Cancelled));

    daemon::daemon_disconnect(handle).await.unwrap();
}

#[tokio::test]
async fn daemon_task_cancel_rejects_unknown_signal() {
    let url = spawn_mock_daemon().await;
    let handle = daemon::daemon_connect(url, TOKEN.into()).await.unwrap();
    let err =
        daemon::daemon_task_cancel(handle.clone(), "t".into(), "sigxyz".into())
            .await
            .unwrap_err();
    assert!(err.starts_with("ERR_BAD_REQUEST"));
    daemon::daemon_disconnect(handle).await.unwrap();
}

#[tokio::test]
async fn daemon_subscribe_then_drain_yields_no_events_until_emitted() {
    let url = spawn_mock_daemon().await;
    let handle = daemon::daemon_connect(url, TOKEN.into()).await.unwrap();
    let task_id = daemon::daemon_task_assign(
        handle.clone(),
        daemon::AiCliKindDto::Generic,
        "x".into(),
        None,
        30,
        None,
    )
    .await
    .unwrap();
    daemon::daemon_subscribe(handle.clone(), task_id)
        .await
        .unwrap();
    // Mock server never emits unsolicited events, so drain returns
    // empty after a short grace window.
    tokio::time::sleep(Duration::from_millis(150)).await;
    let events = daemon::daemon_drain_events(handle.clone(), 0).await.unwrap();
    assert!(events.is_empty());
    daemon::daemon_disconnect(handle).await.unwrap();
}

#[tokio::test]
async fn daemon_drain_events_unknown_handle_errors() {
    let res = daemon::daemon_drain_events("bogus".into(), 0).await;
    assert!(res.is_err());
}

#[tokio::test]
async fn daemon_ws_url_for_local_port_format() {
    assert_eq!(
        daemon::daemon_ws_url_for_local_port(49213),
        "ws://127.0.0.1:49213/v1/stream"
    );
}
