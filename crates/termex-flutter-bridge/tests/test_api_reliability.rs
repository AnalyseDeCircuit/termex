//! Bridge-level tests for the v0.75.0 reliability metrics API.

use std::sync::Mutex;
use tempfile::TempDir;

use termex_core::reliability::TaskMetrics;
use termex_core::storage::db::Database;
use termex_flutter_bridge::api::reliability::*;
use termex_flutter_bridge::db_state;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    dir
}

// task_metrics has an FK to tasks(id), so seed a task row first so
// the cascade column is satisfied.
fn seed_task(id: &str) {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "INSERT OR REPLACE INTO tasks (id, ai_cli_kind, prompt, status, created_at)
                 VALUES (?1, 'claude_code', '', 'pending', ?2)",
                rusqlite::params![id, "2026-05-23T00:00:00Z"],
            )?;
            Ok::<(), rusqlite::Error>(())
        })
        .map_err(|e| e.to_string())
    })
    .unwrap();
}

#[test]
fn get_unknown_returns_none() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    seed_task("t1");
    assert!(reliability_get("t1".into()).unwrap().is_none());
}

#[test]
fn save_then_get_round_trip() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    seed_task("t1");
    let m = TaskMetrics {
        task_id: "t1".into(),
        ws_uptime_ms: 12_000,
        reconnect_count: 3,
        bg_duration_ms: 5_000,
        push_latency_ms: Some(180),
        handoff_count: 1,
        updated_at: "2026-05-23T00:00:00Z".into(),
    };
    reliability_save(m.clone()).unwrap();
    let got = reliability_get("t1".into()).unwrap().unwrap();
    assert_eq!(got, m);
}

#[test]
fn record_reconnect_increments_and_persists() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    seed_task("t1");
    reliability_record_reconnect("t1".into(), "2026-05-23T00:00:00Z".into()).unwrap();
    reliability_record_reconnect("t1".into(), "2026-05-23T00:01:00Z".into()).unwrap();
    let m = reliability_get("t1".into()).unwrap().unwrap();
    assert_eq!(m.reconnect_count, 2);
    assert_eq!(m.updated_at, "2026-05-23T00:01:00Z");
}

#[test]
fn record_ws_session_accumulates() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    seed_task("t1");
    reliability_record_ws_session("t1".into(), 5_000, "2026-05-23T00:00:00Z".into()).unwrap();
    reliability_record_ws_session("t1".into(), 7_500, "2026-05-23T00:01:00Z".into()).unwrap();
    let m = reliability_get("t1".into()).unwrap().unwrap();
    assert_eq!(m.ws_uptime_ms, 12_500);
}

#[test]
fn record_push_latency_overwrites_not_accumulates() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    seed_task("t1");
    reliability_record_push_latency("t1".into(), 500, "2026-05-23T00:00:00Z".into()).unwrap();
    reliability_record_push_latency("t1".into(), 200, "2026-05-23T00:01:00Z".into()).unwrap();
    let m = reliability_get("t1".into()).unwrap().unwrap();
    assert_eq!(m.push_latency_ms, Some(200));
}

#[test]
fn delete_clears_row() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    seed_task("t1");
    reliability_record_reconnect("t1".into(), "2026-05-23T00:00:00Z".into()).unwrap();
    reliability_delete("t1".into()).unwrap();
    assert!(reliability_get("t1".into()).unwrap().is_none());
}

#[test]
fn list_returns_recent_first() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    seed_task("old");
    seed_task("fresh");
    reliability_record_reconnect("old".into(), "2026-05-20T00:00:00Z".into()).unwrap();
    reliability_record_reconnect("fresh".into(), "2026-05-23T00:00:00Z".into()).unwrap();
    let l = reliability_list().unwrap();
    assert_eq!(l[0].task_id, "fresh");
    assert_eq!(l[1].task_id, "old");
}
