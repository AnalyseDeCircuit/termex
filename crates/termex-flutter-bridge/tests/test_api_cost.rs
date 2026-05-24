//! Bridge-level tests for the v0.74.1 cost API. Verifies the
//! Dart-facing entry points correctly delegate to
//! `termex_core::cost` over an unlocked database.

use std::sync::Mutex;
use tempfile::TempDir;

use termex_core::storage::db::Database;
use termex_flutter_bridge::api::cost::*;
use termex_flutter_bridge::db_state;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    dir
}

#[test]
fn cost_estimate_returns_low_lt_high_for_claude_code() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    let e = cost_estimate("claude_code".into(), "refactor the parser".into(), Some(1_000)).unwrap();
    assert_eq!(e.model, "claude-3.5-sonnet");
    assert!(e.cost_usd_high > e.cost_usd_low);
}

#[test]
fn cost_estimate_rejects_unknown_cli() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    let err = cost_estimate("notreal".into(), "x".into(), None).unwrap_err();
    assert!(err.contains("unknown ai_cli kind"));
}

#[test]
fn cost_check_cap_passes_when_all_unlimited() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    let r = cost_check_cap(0.5, None, None, None, 0.0, 0.0).unwrap();
    assert!(!r.blocked);
    assert!(r.kind.is_empty());
}

#[test]
fn cost_check_cap_blocks_single_task_first() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    let r = cost_check_cap(2.0, Some(10.0), Some(1.0), None, 0.0, 0.0).unwrap();
    assert!(r.blocked);
    assert_eq!(r.kind, "single_task");
    assert!((r.cap_amount - 1.0).abs() < 1e-9);
}

#[test]
fn cost_check_cap_blocks_monthly_when_aggregate_overflows() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    let r = cost_check_cap(2.0, Some(10.0), None, None, 9.0, 0.0).unwrap();
    assert!(r.blocked);
    assert_eq!(r.kind, "monthly");
}

#[test]
fn cost_record_then_total_for_task() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    cost_record(
        "r1".into(),
        "t1".into(),
        "s1".into(),
        "primary_ai_call".into(),
        "claude-3.5-sonnet".into(),
        1_000,
        500,
        0.0105,
        "2026-05-01T00:00:00Z".into(),
    )
    .unwrap();
    cost_record(
        "r2".into(),
        "t1".into(),
        "s1".into(),
        "tool_use".into(),
        "claude-3.5-sonnet".into(),
        0,
        0,
        0.0,
        "2026-05-01T00:01:00Z".into(),
    )
    .unwrap();
    let total = cost_total_for_task("t1".into()).unwrap();
    assert!((total - 0.0105).abs() < 1e-9);
}

#[test]
fn cost_record_rejects_unknown_kind() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    let err = cost_record(
        "r1".into(),
        "t1".into(),
        "s1".into(),
        "made_up_kind".into(),
        "x".into(),
        0,
        0,
        0.0,
        "2026-05-01T00:00:00Z".into(),
    )
    .unwrap_err();
    assert!(err.contains("unknown cost kind"));
}

#[test]
fn cost_summary_period_label_passes_through() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    cost_record(
        "r1".into(),
        "tA".into(),
        "s1".into(),
        "primary_ai_call".into(),
        "claude-3.5-sonnet".into(),
        100,
        50,
        0.10,
        "2026-05-10T00:00:00Z".into(),
    )
    .unwrap();
    let s = cost_summary("2026-05-01T00:00:00Z".into(), "This month".into(), 5).unwrap();
    assert_eq!(s.period_label, "This month");
    assert!((s.total_usd - 0.10).abs() < 1e-9);
    assert_eq!(s.task_count, 1);
}
