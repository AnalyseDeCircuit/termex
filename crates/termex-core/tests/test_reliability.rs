//! Integration tests for the reliability metrics module — pure
//! update helpers + SQLite storage.

use rusqlite::Connection;

use termex_core::reliability::metrics::{
    record_bg_duration, record_handoff, record_push_latency, record_reconnect,
    record_ws_session,
};
use termex_core::reliability::storage::{delete, ensure_schema, get, list, save};
use termex_core::reliability::TaskMetrics;

const T0: &str = "2026-05-23T00:00:00Z";
const T1: &str = "2026-05-23T00:01:00Z";

fn db() -> Connection {
    let c = Connection::open_in_memory().unwrap();
    ensure_schema(&c).unwrap();
    c
}

// ── DTO ────────────────────────────────────────────────────────────

#[test]
fn empty_initializes_all_counters_to_zero() {
    let m = TaskMetrics::empty("t1", T0);
    assert_eq!(m.task_id, "t1");
    assert_eq!(m.ws_uptime_ms, 0);
    assert_eq!(m.reconnect_count, 0);
    assert_eq!(m.bg_duration_ms, 0);
    assert_eq!(m.push_latency_ms, None);
    assert_eq!(m.handoff_count, 0);
    assert_eq!(m.updated_at, T0);
}

// ── update helpers ─────────────────────────────────────────────────

#[test]
fn record_ws_session_accumulates_uptime() {
    let m = TaskMetrics::empty("t1", T0);
    let m1 = record_ws_session(&m, 5_000, T1);
    assert_eq!(m1.ws_uptime_ms, 5_000);
    let m2 = record_ws_session(&m1, 7_500, T1);
    assert_eq!(m2.ws_uptime_ms, 12_500);
    assert_eq!(m2.updated_at, T1);
}

#[test]
fn record_ws_session_saturates_on_overflow() {
    let mut m = TaskMetrics::empty("t1", T0);
    m.ws_uptime_ms = u64::MAX - 100;
    let m1 = record_ws_session(&m, 1_000, T1);
    assert_eq!(m1.ws_uptime_ms, u64::MAX);
}

#[test]
fn record_reconnect_increments_by_one() {
    let m = TaskMetrics::empty("t1", T0);
    let m1 = record_reconnect(&m, T1);
    let m2 = record_reconnect(&m1, T1);
    let m3 = record_reconnect(&m2, T1);
    assert_eq!(m3.reconnect_count, 3);
}

#[test]
fn record_reconnect_saturates_at_u32_max() {
    let mut m = TaskMetrics::empty("t1", T0);
    m.reconnect_count = u32::MAX;
    let m1 = record_reconnect(&m, T1);
    assert_eq!(m1.reconnect_count, u32::MAX);
}

#[test]
fn record_bg_duration_accumulates() {
    let m = TaskMetrics::empty("t1", T0);
    let m1 = record_bg_duration(&m, 30_000, T1);
    let m2 = record_bg_duration(&m1, 60_000, T1);
    assert_eq!(m2.bg_duration_ms, 90_000);
}

#[test]
fn record_push_latency_overwrites_not_accumulates() {
    let m = TaskMetrics::empty("t1", T0);
    let m1 = record_push_latency(&m, 800, T1);
    let m2 = record_push_latency(&m1, 200, T1);
    assert_eq!(m2.push_latency_ms, Some(200));
}

#[test]
fn record_handoff_increments() {
    let m = TaskMetrics::empty("t1", T0);
    let m1 = record_handoff(&m, T1);
    let m2 = record_handoff(&m1, T1);
    assert_eq!(m2.handoff_count, 2);
}

#[test]
fn update_helpers_preserve_unrelated_fields() {
    let mut m = TaskMetrics::empty("t1", T0);
    m.reconnect_count = 5;
    m.bg_duration_ms = 2_000;
    m.push_latency_ms = Some(150);
    m.handoff_count = 1;
    let m1 = record_ws_session(&m, 1_000, T1);
    assert_eq!(m1.reconnect_count, 5);
    assert_eq!(m1.bg_duration_ms, 2_000);
    assert_eq!(m1.push_latency_ms, Some(150));
    assert_eq!(m1.handoff_count, 1);
    assert_eq!(m1.ws_uptime_ms, 1_000);
}

// ── storage ────────────────────────────────────────────────────────

#[test]
fn save_then_get_round_trip() {
    let c = db();
    let m = TaskMetrics {
        task_id: "t1".into(),
        ws_uptime_ms: 12_345,
        reconnect_count: 4,
        bg_duration_ms: 9_876,
        push_latency_ms: Some(220),
        handoff_count: 2,
        updated_at: T1.into(),
    };
    save(&c, &m).unwrap();
    let got = get(&c, "t1").unwrap().unwrap();
    assert_eq!(got, m);
}

#[test]
fn save_upserts_on_duplicate_task_id() {
    let c = db();
    let m = TaskMetrics::empty("t1", T0);
    save(&c, &m).unwrap();
    let updated = record_reconnect(&m, T1);
    save(&c, &updated).unwrap();
    let got = get(&c, "t1").unwrap().unwrap();
    assert_eq!(got.reconnect_count, 1);
    assert_eq!(got.updated_at, T1);
}

#[test]
fn get_unknown_returns_none() {
    let c = db();
    assert!(get(&c, "nope").unwrap().is_none());
}

#[test]
fn delete_removes_row() {
    let c = db();
    save(&c, &TaskMetrics::empty("t1", T0)).unwrap();
    delete(&c, "t1").unwrap();
    assert!(get(&c, "t1").unwrap().is_none());
}

#[test]
fn delete_unknown_is_silent_noop() {
    let c = db();
    delete(&c, "nope").unwrap();
}

#[test]
fn list_sorted_by_updated_at_desc() {
    let c = db();
    save(
        &c,
        &TaskMetrics {
            task_id: "old".into(),
            updated_at: "2026-05-20T00:00:00Z".into(),
            ..TaskMetrics::empty("old", T0)
        },
    )
    .unwrap();
    save(
        &c,
        &TaskMetrics {
            task_id: "new".into(),
            updated_at: "2026-05-23T00:00:00Z".into(),
            ..TaskMetrics::empty("new", T0)
        },
    )
    .unwrap();
    let l = list(&c).unwrap();
    assert_eq!(l[0].task_id, "new");
    assert_eq!(l[1].task_id, "old");
}

#[test]
fn push_latency_none_round_trips_as_null() {
    let c = db();
    let m = TaskMetrics::empty("t1", T0); // push_latency_ms = None
    save(&c, &m).unwrap();
    let got = get(&c, "t1").unwrap().unwrap();
    assert_eq!(got.push_latency_ms, None);
}

#[test]
fn large_counter_values_round_trip() {
    let c = db();
    let m = TaskMetrics {
        task_id: "big".into(),
        ws_uptime_ms: u64::MAX / 2,
        reconnect_count: u32::MAX,
        bg_duration_ms: u64::MAX / 4,
        push_latency_ms: Some(u32::MAX),
        handoff_count: u32::MAX - 1,
        updated_at: T0.into(),
    };
    save(&c, &m).unwrap();
    let got = get(&c, "big").unwrap().unwrap();
    assert_eq!(got, m);
}
