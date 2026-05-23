//! Event log + stream replay tests.

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

use std::sync::Arc;

use tokio::sync::Mutex;

use termex_core::daemon::ServerMessage;
use termex_core::task::TaskStatus;

use crate::db::Database;
use crate::event_log::EventLog;

fn make_log_with_capacity(cap: usize) -> EventLog {
    let db = Arc::new(Mutex::new(Database::in_memory().unwrap()));
    EventLog::with_capacity(db, cap)
}

fn output(task_id: &str, seq: u64) -> ServerMessage {
    ServerMessage::TaskOutput {
        task_id: task_id.into(),
        stream: termex_core::daemon::OutputStream::Stdout,
        data: format!("chunk-{seq}"),
        seq,
        ts_ms: 1000 + seq,
    }
}

fn status(task_id: &str, seq: u64, status: TaskStatus) -> ServerMessage {
    ServerMessage::TaskStatus {
        task_id: task_id.into(),
        status,
        exit_code: Some(0),
        duration_ms: Some(100),
        seq,
        ts_ms: 2000 + seq,
    }
}

#[tokio::test]
async fn push_then_replay_hot_only() {
    let log = make_log_with_capacity(32);
    for i in 1..=10 {
        log.push(i, &output("t1", i)).await;
    }
    let replayed = log.replay_since(5, 100).await;
    assert_eq!(replayed.len(), 5);
    assert_eq!(replayed.first().unwrap().seq, 6);
    assert_eq!(replayed.last().unwrap().seq, 10);
}

#[tokio::test]
async fn replay_respects_limit() {
    let log = make_log_with_capacity(32);
    for i in 1..=10 {
        log.push(i, &output("t1", i)).await;
    }
    let replayed = log.replay_since(0, 3).await;
    assert_eq!(replayed.len(), 3);
    assert_eq!(replayed[0].seq, 1);
    assert_eq!(replayed[2].seq, 3);
}

#[tokio::test]
async fn replay_returns_empty_when_caught_up() {
    let log = make_log_with_capacity(32);
    for i in 1..=5 {
        log.push(i, &output("t1", i)).await;
    }
    let replayed = log.replay_since(10, 100).await;
    assert!(replayed.is_empty());
}

#[tokio::test]
async fn replay_falls_back_to_cold_db_after_eviction() {
    // Hot capacity is intentionally small so old entries evict.
    let log = make_log_with_capacity(3);
    for i in 1..=10 {
        log.push(i, &output("t1", i)).await;
    }
    assert!(log.hot_len() <= 3);

    // Ask for events 1..=10 — hot only has 8..=10 so cold must serve.
    let replayed = log.replay_since(0, 100).await;
    assert_eq!(replayed.len(), 10);
    for (i, e) in replayed.iter().enumerate() {
        assert_eq!(e.seq, (i as u64) + 1);
    }
}

#[tokio::test]
async fn replay_preserves_message_content() {
    let log = make_log_with_capacity(32);
    let msg = status("t1", 7, TaskStatus::Succeeded);
    log.push(7, &msg).await;
    let replayed = log.replay_since(0, 100).await;
    assert_eq!(replayed.len(), 1);
    match &replayed[0].message {
        ServerMessage::TaskStatus {
            task_id,
            status,
            exit_code,
            ..
        } => {
            assert_eq!(task_id, "t1");
            assert_eq!(*status, TaskStatus::Succeeded);
            assert_eq!(*exit_code, Some(0));
        }
        other => panic!("expected TaskStatus, got {other:?}"),
    }
}

#[tokio::test]
async fn push_persists_to_cold_db() {
    let db = Arc::new(Mutex::new(Database::in_memory().unwrap()));
    let log = EventLog::with_capacity(db.clone(), 1);
    for i in 1..=5 {
        log.push(i, &output("t1", i)).await;
    }
    let n = db.lock().await.events_log_count().unwrap();
    assert_eq!(n, 5);
}

#[tokio::test]
async fn prune_events_drops_old_rows() {
    let db = Arc::new(Mutex::new(Database::in_memory().unwrap()));
    let log = EventLog::with_capacity(db.clone(), 32);
    log.push(1, &output("t1", 1)).await; // ts_ms = 1001
    log.push(2, &output("t1", 2)).await; // ts_ms = 1002
    log.push(3, &output("t1", 3)).await; // ts_ms = 1003

    let pruned = db.lock().await.prune_events_before(1002).unwrap();
    assert_eq!(pruned, 1, "only ts_ms < 1002 → row with seq=1");
    let remaining = db.lock().await.events_log_count().unwrap();
    assert_eq!(remaining, 2);
}

#[tokio::test]
async fn schema_version_is_two_after_open() {
    let db = Database::in_memory().unwrap();
    assert_eq!(db.schema_version().unwrap(), 2);
}
