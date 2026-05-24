//! Integration tests for the v0.74.1 daemon-side cost recorder.

#[path = "../src/db.rs"]
#[allow(dead_code)]
mod db;

#[path = "../src/error.rs"]
#[allow(dead_code)]
mod error;

#[path = "../src/cost_recorder.rs"]
#[allow(dead_code)]
mod cost_recorder;

use std::sync::Arc;

use tokio::sync::Mutex;

use termex_core::cost::CostKind;

use cost_recorder::CostRecorder;
use db::Database;

fn rec() -> (CostRecorder, Arc<Mutex<Database>>) {
    let db = Arc::new(Mutex::new(Database::in_memory().unwrap()));
    (CostRecorder::new(db.clone()), db)
}

#[tokio::test]
async fn record_usage_writes_a_row() {
    let (r, _db) = rec();
    r.record_usage(
        "t1",
        "s1",
        CostKind::PrimaryAiCall,
        "claude-3.5-sonnet",
        1_000,
        500,
    )
    .await;
    let total = r.total_for_task("t1").await;
    // 1000 in @ $0.003/k + 500 out @ $0.015/k = 0.003 + 0.0075 = 0.0105
    assert!((total - 0.0105).abs() < 1e-9, "got {total}");
}

#[tokio::test]
async fn record_usage_accumulates_across_calls() {
    let (r, _db) = rec();
    for _ in 0..3 {
        r.record_usage("t1", "", CostKind::PrimaryAiCall, "claude-3.5-sonnet", 100, 50)
            .await;
    }
    let total = r.total_for_task("t1").await;
    // 0.00075 * 3 = 0.00225 — within 4-decimal rounding floor.
    assert!(total > 0.0, "expected positive total, got {total}");
}

#[tokio::test]
async fn record_usage_unknown_model_uses_fallback_pricing() {
    let (r, _db) = rec();
    r.record_usage("t1", "", CostKind::PrimaryAiCall, "future-model-9", 1_000, 500)
        .await;
    let total = r.total_for_task("t1").await;
    // Fallback = claude-3.5-sonnet → same 0.0105
    assert!((total - 0.0105).abs() < 1e-9);
}

#[tokio::test]
async fn record_usage_zero_tokens_records_zero_cost() {
    let (r, _db) = rec();
    r.record_usage("t1", "", CostKind::ToolUse, "claude-3.5-sonnet", 0, 0)
        .await;
    let total = r.total_for_task("t1").await;
    assert_eq!(total, 0.0);
}

#[tokio::test]
async fn total_for_unknown_task_is_zero() {
    let (r, _db) = rec();
    assert_eq!(r.total_for_task("never-existed").await, 0.0);
}

#[tokio::test]
async fn record_usage_separates_tasks() {
    let (r, _db) = rec();
    r.record_usage("t1", "", CostKind::PrimaryAiCall, "claude-3.5-sonnet", 1_000, 500)
        .await;
    r.record_usage("t2", "", CostKind::PrimaryAiCall, "claude-3.5-sonnet", 2_000, 1_000)
        .await;
    let total_t1 = r.total_for_task("t1").await;
    let total_t2 = r.total_for_task("t2").await;
    assert!((total_t1 - 0.0105).abs() < 1e-9);
    assert!((total_t2 - 0.021).abs() < 1e-9);
}
