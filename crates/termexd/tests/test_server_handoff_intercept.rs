//! Tests for the v0.74.2 server-side handoff intercept that
//! injects per-connection device identity into HandoffSend /
//! Takeover / StateSync messages. Verifies the wire response
//! payload + the runtime side-effects.

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

#[path = "../src/cost_recorder.rs"]
#[allow(dead_code)]
mod cost_recorder;

#[path = "../src/supervisor.rs"]
#[allow(dead_code)]
mod supervisor;

#[path = "../src/handler.rs"]
#[allow(dead_code)]
mod handler;

#[path = "../src/server.rs"]
#[allow(dead_code)]
mod server;

#[path = "../src/auth.rs"]
#[allow(dead_code)]
mod auth;

#[path = "../src/mcp/mod.rs"]
#[allow(dead_code)]
mod mcp;

use std::sync::Arc;

use termex_core::daemon::{ClientMessage, DeviceWireDto, ServerMessage};

use db::Database;
use event_bus::EventBus;
use handler::HandlerCtx;
use server::try_intercept_handoff;

fn ctx_with_runtime() -> Arc<HandlerCtx> {
    let bus = EventBus::new();
    let db = Database::in_memory().unwrap();
    HandlerCtx::new_no_spawn(db, bus)
}

fn dev(id: &str, name: &str) -> DeviceWireDto {
    DeviceWireDto {
        id: id.into(),
        name: name.into(),
        platform: "ios".into(),
    }
}

fn unwrap_response(resp: ServerMessage) -> (bool, serde_json::Value, Option<String>) {
    match resp {
        ServerMessage::Response { ok, data, code, .. } => (ok, data, code),
        other => panic!("expected Response, got {other:?}"),
    }
}

// ── identity bypass ────────────────────────────────────────────────

#[tokio::test]
async fn no_connection_device_falls_through_to_handler() {
    let ctx = ctx_with_runtime();
    let msg = ClientMessage::HandoffSend {
        request_id: "r1".into(),
        task_id: "t1".into(),
        target_device_id: "anywhere".into(),
        deep_link: "termex://task/t1".into(),
    };
    // None → intercept returns None → caller falls through to the
    // handler's placeholder behaviour. Test that we get None back.
    assert!(try_intercept_handoff(&ctx, &msg, &None).await.is_none());
}

#[tokio::test]
async fn non_handoff_messages_fall_through() {
    let ctx = ctx_with_runtime();
    let msg = ClientMessage::Ping {
        request_id: "r1".into(),
        ts_ms: 0,
    };
    let device = Some(dev("A", "A"));
    assert!(try_intercept_handoff(&ctx, &msg, &device).await.is_none());
}

// ── HandoffSend routing ────────────────────────────────────────────

#[tokio::test]
async fn handoff_send_unknown_target_returns_not_found() {
    let ctx = ctx_with_runtime();
    let device = Some(dev("A", "A"));
    let msg = ClientMessage::HandoffSend {
        request_id: "r1".into(),
        task_id: "t1".into(),
        target_device_id: "no-such-device".into(),
        deep_link: "termex://task/t1".into(),
    };
    let resp = try_intercept_handoff(&ctx, &msg, &device).await.unwrap();
    let (ok, _data, code) = unwrap_response(resp);
    assert!(!ok);
    assert_eq!(code.as_deref(), Some("ERR_NOT_FOUND"));
}

#[tokio::test]
async fn handoff_send_registered_offline_queues() {
    let ctx = ctx_with_runtime();
    // Register target so the runtime knows it exists, but never call
    // on_connect → it's "offline" → queued.
    ctx.handoff
        .register_device("B", "Mac", "macos", None, None)
        .await
        .unwrap();
    let device = Some(dev("A", "A"));
    let msg = ClientMessage::HandoffSend {
        request_id: "r1".into(),
        task_id: "t1".into(),
        target_device_id: "B".into(),
        deep_link: "termex://task/t1".into(),
    };
    let resp = try_intercept_handoff(&ctx, &msg, &device).await.unwrap();
    let (ok, data, _) = unwrap_response(resp);
    assert!(ok);
    assert_eq!(data["delivery_path"], "queued");
}

#[tokio::test]
async fn handoff_send_online_target_delivers_via_ws() {
    let ctx = ctx_with_runtime();
    ctx.handoff
        .register_device("B", "Mac", "macos", None, None)
        .await
        .unwrap();
    // Wire B's sink via on_connect so the runtime can deliver.
    let (sink, mut rx) = handoff::ChannelSink::new();
    ctx.handoff.on_connect("B", sink).await.unwrap();

    let device = Some(dev("A", "iPhone"));
    let msg = ClientMessage::HandoffSend {
        request_id: "r1".into(),
        task_id: "t1".into(),
        target_device_id: "B".into(),
        deep_link: "termex://task/t1".into(),
    };
    let resp = try_intercept_handoff(&ctx, &msg, &device).await.unwrap();
    let (ok, data, _) = unwrap_response(resp);
    assert!(ok);
    assert_eq!(data["delivery_path"], "ws");

    // Critical: the HandoffReceived push must carry the *real* sender
    // identity ("A"/"iPhone"), not the legacy "self" placeholder.
    let pushed = rx.recv().await.unwrap();
    match pushed {
        ServerMessage::HandoffReceived { from_device, .. } => {
            assert_eq!(from_device.id, "A");
            assert_eq!(from_device.name, "iPhone");
        }
        other => panic!("expected HandoffReceived, got {other:?}"),
    }
}

// ── HandoffTakeover routing ────────────────────────────────────────

#[tokio::test]
async fn handoff_takeover_unowned_wins_and_records_real_owner() {
    let ctx = ctx_with_runtime();
    ctx.handoff.insert_task_for_test("t1").await;

    let device = Some(dev("A", "A"));
    let msg = ClientMessage::HandoffTakeover {
        request_id: "r1".into(),
        task_id: "t1".into(),
        expected_previous_owner: None,
    };
    let resp = try_intercept_handoff(&ctx, &msg, &device).await.unwrap();
    let (ok, data, code) = unwrap_response(resp);
    assert!(ok);
    assert!(code.is_none());
    assert!(data["previous_owner_id"].is_null());
    // Critical: the runtime now thinks A owns the task — not "self".
    let owner = ctx.handoff.current_owner("t1").await.unwrap();
    assert_eq!(owner.as_deref(), Some("A"));
}

#[tokio::test]
async fn handoff_takeover_race_returns_ownership_changed() {
    let ctx = ctx_with_runtime();
    ctx.handoff.insert_task_for_test("t1").await;
    ctx.handoff
        .try_take_over("t1", &dev("A", "A"), None)
        .await
        .unwrap();

    // B tries to take from A but passes a stale expectation.
    let device = Some(dev("B", "B"));
    let msg = ClientMessage::HandoffTakeover {
        request_id: "r1".into(),
        task_id: "t1".into(),
        expected_previous_owner: Some("ghost".into()),
    };
    let resp = try_intercept_handoff(&ctx, &msg, &device).await.unwrap();
    let (ok, data, code) = unwrap_response(resp);
    assert!(!ok);
    assert_eq!(code.as_deref(), Some("OWNERSHIP_CHANGED"));
    assert_eq!(data["actual_owner_id"], "A");
}

// ── HandoffStateSync routing ────────────────────────────────────────

#[tokio::test]
async fn handoff_state_sync_fanout_excludes_sender() {
    let ctx = ctx_with_runtime();
    for id in ["A", "B", "C"] {
        ctx.handoff.register_device(id, id, "ios", None, None).await.unwrap();
    }
    let (sa, mut ra) = handoff::ChannelSink::new();
    let (sb, mut rb) = handoff::ChannelSink::new();
    let (sc, mut rc) = handoff::ChannelSink::new();
    ctx.handoff.on_connect("A", sa).await.unwrap();
    ctx.handoff.on_connect("B", sb).await.unwrap();
    ctx.handoff.on_connect("C", sc).await.unwrap();
    ctx.handoff.subscribe("t1", "A").await;
    ctx.handoff.subscribe("t1", "B").await;
    ctx.handoff.subscribe("t1", "C").await;

    let device = Some(dev("A", "iPhone"));
    let msg = ClientMessage::HandoffStateSync {
        request_id: "r1".into(),
        task_id: "t1".into(),
        ui_state: serde_json::json!({ "scroll_pct": 0.42 }),
    };
    let resp = try_intercept_handoff(&ctx, &msg, &device).await.unwrap();
    let (ok, data, _) = unwrap_response(resp);
    assert!(ok);
    assert_eq!(data["fanout"], 2); // B and C, not A
    assert!(ra.try_recv().is_err(), "sender must not receive its own echo");
    assert!(rb.recv().await.is_some());
    assert!(rc.recv().await.is_some());
}
