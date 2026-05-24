//! Integration tests for the v0.74.2 handoff runtime — watcher
//! routing, takeover ownership lock, and state-sync broadcast.

#[path = "../src/db.rs"]
#[allow(dead_code)]
mod db;

#[path = "../src/error.rs"]
#[allow(dead_code)]
mod error;

#[path = "../src/handoff.rs"]
#[allow(dead_code)]
mod handoff;

use std::sync::Arc;

use termex_core::daemon::{DeviceWireDto, ServerMessage};
use termex_core::handoff::TakeoverOutcome;

use db::Database;
use handoff::{ChannelSink, DeliveryOutcome, HandoffRuntime};

fn rt() -> HandoffRuntime {
    let db = Arc::new(tokio::sync::Mutex::new(Database::in_memory().unwrap()));
    HandoffRuntime::new(db)
}

fn dev(id: &str, name: &str, platform: &str) -> DeviceWireDto {
    DeviceWireDto {
        id: id.into(),
        name: name.into(),
        platform: platform.into(),
    }
}

#[tokio::test]
async fn register_device_persists_to_registry() {
    let r = rt();
    r.register_device("d1", "iPhone", "ios", Some("apns-token"), Some("ios_apns"))
        .await
        .unwrap();
    // Re-register with different name → upsert
    r.register_device("d1", "iPhone 15", "ios", None, None)
        .await
        .unwrap();
    let owner = r.current_owner("any-task").await.unwrap();
    assert!(owner.is_none()); // sanity — no ownership yet
}

#[tokio::test]
async fn register_unknown_platform_errors() {
    let r = rt();
    let err = r
        .register_device("d1", "x", "plan9", None, None)
        .await
        .unwrap_err();
    assert!(err.to_string().contains("plan9"));
}

#[tokio::test]
async fn subscribe_returns_watchers_with_known_names() {
    let r = rt();
    r.register_device("d1", "iPhone", "ios", None, None)
        .await
        .unwrap();
    r.register_device("d2", "MacBook", "macos", None, None)
        .await
        .unwrap();

    let after_first = r.subscribe("t1", "d1").await;
    assert_eq!(after_first.len(), 1);
    assert_eq!(after_first[0].name, "iPhone");

    let after_second = r.subscribe("t1", "d2").await;
    assert_eq!(after_second.len(), 2);
}

#[tokio::test]
async fn unsubscribe_removes_then_disconnect_cleans_up() {
    let r = rt();
    r.register_device("d1", "A", "ios", None, None).await.unwrap();
    r.register_device("d2", "B", "macos", None, None).await.unwrap();
    r.subscribe("t1", "d1").await;
    r.subscribe("t1", "d2").await;

    let remaining = r.unsubscribe("t1", "d1").await;
    assert_eq!(remaining.len(), 1);
    assert_eq!(remaining[0].id, "d2");

    let touched = r.on_disconnect("d2");
    assert_eq!(touched, vec!["t1"]);
    assert!(r.watchers("t1").await.is_empty());
}

#[tokio::test]
async fn send_handoff_to_online_target_delivers_over_ws() {
    let r = rt();
    r.register_device("from", "From", "ios", None, None)
        .await
        .unwrap();
    r.register_device("to", "To", "macos", None, None)
        .await
        .unwrap();

    let (sink, mut rx) = ChannelSink::new();
    r.on_connect("to", sink).await.unwrap();

    let outcome = r
        .send_handoff(
            "t1",
            dev("from", "From", "ios"),
            "to",
            "termex://task/t1",
        )
        .await;
    assert_eq!(outcome, DeliveryOutcome::DeliveredWs);

    let msg = rx.recv().await.expect("target should receive handoff");
    match msg {
        ServerMessage::HandoffReceived {
            task_id,
            from_device,
            deep_link,
            ..
        } => {
            assert_eq!(task_id, "t1");
            assert_eq!(from_device.id, "from");
            assert_eq!(deep_link, "termex://task/t1");
        }
        other => panic!("expected HandoffReceived, got {other:?}"),
    }
}

#[tokio::test]
async fn send_handoff_to_registered_but_offline_returns_offline() {
    let r = rt();
    r.register_device("to", "To", "macos", None, None)
        .await
        .unwrap();
    let outcome = r
        .send_handoff("t1", dev("from", "From", "ios"), "to", "termex://task/t1")
        .await;
    assert_eq!(outcome, DeliveryOutcome::Offline);
}

#[tokio::test]
async fn send_handoff_to_unknown_target_returns_unknown() {
    let r = rt();
    let outcome = r
        .send_handoff(
            "t1",
            dev("from", "From", "ios"),
            "no-such-device",
            "termex://task/t1",
        )
        .await;
    assert_eq!(outcome, DeliveryOutcome::UnknownTarget);
}

#[tokio::test]
async fn takeover_unowned_wins_and_sets_ownership() {
    let r = rt();
    r.insert_task_for_test("t1").await;
    let new_owner = dev("A", "A", "ios");
    let outcome = r
        .try_take_over("t1", &new_owner, None)
        .await
        .unwrap();
    assert_eq!(
        outcome,
        TakeoverOutcome::Won {
            previous_owner_id: None
        }
    );
    assert_eq!(r.current_owner("t1").await.unwrap().as_deref(), Some("A"));
}

#[tokio::test]
async fn takeover_with_expected_match_swaps_and_notifies_prev() {
    let r = rt();
    r.insert_task_for_test("t1").await;
    r.try_take_over("t1", &dev("A", "A", "ios"), None)
        .await
        .unwrap();

    // Wire up A's sink so we can observe the taken_over notification.
    let (sink, mut rx) = ChannelSink::new();
    r.on_connect("A", sink).await.unwrap();

    let outcome = r
        .try_take_over("t1", &dev("B", "B", "macos"), Some("A"))
        .await
        .unwrap();
    assert_eq!(
        outcome,
        TakeoverOutcome::Won {
            previous_owner_id: Some("A".into())
        }
    );
    assert_eq!(r.current_owner("t1").await.unwrap().as_deref(), Some("B"));

    let msg = rx.recv().await.expect("A should hear the takeover");
    match msg {
        ServerMessage::TaskTakenOver { task_id, new_owner, .. } => {
            assert_eq!(task_id, "t1");
            assert_eq!(new_owner.id, "B");
        }
        other => panic!("expected TaskTakenOver, got {other:?}"),
    }
}

#[tokio::test]
async fn takeover_with_stale_expectation_loses_race() {
    let r = rt();
    r.insert_task_for_test("t1").await;
    r.try_take_over("t1", &dev("A", "A", "ios"), None)
        .await
        .unwrap();
    r.try_take_over("t1", &dev("B", "B", "macos"), Some("A"))
        .await
        .unwrap();

    let outcome = r
        .try_take_over("t1", &dev("C", "C", "linux"), Some("A"))
        .await
        .unwrap();
    match outcome {
        TakeoverOutcome::RaceLost { actual_owner_id } => {
            assert_eq!(actual_owner_id.as_deref(), Some("B"));
        }
        other => panic!("expected RaceLost, got {other:?}"),
    }
    assert_eq!(r.current_owner("t1").await.unwrap().as_deref(), Some("B"));
}

#[tokio::test]
async fn broadcast_state_fans_out_to_other_watchers_only() {
    let r = rt();
    for id in ["A", "B", "C"] {
        r.register_device(id, id, "ios", None, None).await.unwrap();
    }
    let (sink_a, mut rx_a) = ChannelSink::new();
    let (sink_b, mut rx_b) = ChannelSink::new();
    let (sink_c, mut rx_c) = ChannelSink::new();
    r.on_connect("A", sink_a).await.unwrap();
    r.on_connect("B", sink_b).await.unwrap();
    r.on_connect("C", sink_c).await.unwrap();
    r.subscribe("t1", "A").await;
    r.subscribe("t1", "B").await;
    r.subscribe("t1", "C").await;

    let fanout = r.broadcast_state(
        "t1",
        dev("A", "A", "ios"),
        serde_json::json!({ "scroll_pct": 0.75 }),
    );
    assert_eq!(fanout, 2); // B and C, not A

    // Sender should NOT receive its own state echo.
    assert!(rx_a.try_recv().is_err());
    let _ = rx_b.recv().await.expect("B receives");
    let _ = rx_c.recv().await.expect("C receives");
}

#[tokio::test]
async fn broadcast_state_no_watchers_returns_zero() {
    let r = rt();
    let fanout = r.broadcast_state(
        "ghost-task",
        dev("A", "A", "ios"),
        serde_json::Value::Null,
    );
    assert_eq!(fanout, 0);
}
