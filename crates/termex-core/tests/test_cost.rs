//! Integration tests for the cost tracker — pricing, estimation,
//! cap evaluation, and SQLite-backed aggregation.

use rusqlite::Connection;

use termex_core::cost::estimator::{check_cap, estimate_task_cost};
use termex_core::cost::pricing::{ModelPrice, ModelPricing};
use termex_core::cost::storage::{
    ensure_schema, insert, summary_since, total_for_task, total_in_range,
};
use termex_core::cost::{CapDecision, CapKind, CostKind, CostRecord, UserCostCap};
use termex_core::task::AiCliKind;

fn db() -> Connection {
    let c = Connection::open_in_memory().unwrap();
    ensure_schema(&c).unwrap();
    c
}

fn rec(
    id: &str,
    task: &str,
    server: &str,
    kind: CostKind,
    model: &str,
    inp: u64,
    out: u64,
    cost: f64,
    ts: &str,
) -> CostRecord {
    CostRecord {
        id: id.into(),
        task_id: task.into(),
        server_id: server.into(),
        kind,
        model: model.into(),
        input_tokens: inp,
        output_tokens: out,
        cost_usd: cost,
        ts: ts.into(),
    }
}

// ── pricing ─────────────────────────────────────────────────────────

#[test]
fn pricing_default_knows_canonical_models() {
    let p = ModelPricing::default();
    assert!(p.knows("claude-3.5-sonnet"));
    assert!(p.knows("gpt-4o"));
    assert!(p.knows("o1"));
}

#[test]
fn pricing_calculate_sonnet_round_trip() {
    let p = ModelPricing::default();
    // 1000 in + 500 out @ sonnet = 0.003 + 0.0075 = 0.0105
    let c = p.calculate("claude-3.5-sonnet", 1_000, 500);
    assert!((c - 0.0105).abs() < 1e-9, "got {c}");
}

#[test]
fn pricing_unknown_model_falls_back_to_sonnet() {
    let p = ModelPricing::default();
    let unknown = p.calculate("claude-5-ultra-future", 1_000, 500);
    let sonnet = p.calculate("claude-3.5-sonnet", 1_000, 500);
    assert_eq!(unknown, sonnet);
}

#[test]
fn pricing_user_override_replaces_entry() {
    let mut p = ModelPricing::default();
    p.set(
        "claude-3.5-sonnet",
        ModelPrice {
            input_per_1k: 0.001,
            output_per_1k: 0.005,
        },
    );
    // 1k in + 1k out at new rate = 0.001 + 0.005 = 0.006
    assert!((p.calculate("claude-3.5-sonnet", 1_000, 1_000) - 0.006).abs() < 1e-9);
}

#[test]
fn pricing_round_to_4_decimals() {
    let p = ModelPricing::default();
    // 1 input token @ 0.003/1k = 0.000003 → rounds to 0.0000
    let c = p.calculate("claude-3.5-sonnet", 1, 0);
    assert_eq!(c, 0.0);
    // 100 input tokens = 0.0003 → exact 4-decimal value.
    let c2 = p.calculate("claude-3.5-sonnet", 100, 0);
    assert!((c2 - 0.0003).abs() < 1e-9);
}

// ── estimator ───────────────────────────────────────────────────────

#[test]
fn estimate_uses_historical_avg_when_provided() {
    let p = ModelPricing::default();
    let e = estimate_task_cost(AiCliKind::ClaudeCode, "refactor the parser", Some(1_000), &p);
    assert_eq!(e.model, "claude-3.5-sonnet");
    assert_eq!(e.output_tokens_est, 1_000);
    // low uses half (500), high uses double (2000) of avg
    assert!(e.cost_usd_high > e.cost_usd_low);
}

#[test]
fn estimate_defaults_output_when_no_history() {
    let p = ModelPricing::default();
    let e = estimate_task_cost(AiCliKind::ClaudeCode, "hi", None, &p);
    assert_eq!(e.output_tokens_est, 2_000);
}

#[test]
fn estimate_per_cli_default_model() {
    let p = ModelPricing::default();
    assert_eq!(
        estimate_task_cost(AiCliKind::Codex, "x", None, &p).model,
        "gpt-4o"
    );
    assert_eq!(
        estimate_task_cost(AiCliKind::Generic, "x", None, &p).model,
        "claude-3-haiku"
    );
}

#[test]
fn estimate_input_tokens_scale_with_prompt_length() {
    let p = ModelPricing::default();
    let short = estimate_task_cost(AiCliKind::ClaudeCode, "hi", None, &p);
    let long_prompt = "a".repeat(4_000);
    let long = estimate_task_cost(AiCliKind::ClaudeCode, &long_prompt, None, &p);
    assert!(long.input_tokens_est > short.input_tokens_est);
}

// ── cap evaluator ───────────────────────────────────────────────────

fn sample_estimate(high: f64) -> termex_core::cost::estimator::CostEstimate {
    termex_core::cost::estimator::CostEstimate {
        model: "claude-3.5-sonnet".into(),
        input_tokens_est: 100,
        output_tokens_est: 2_000,
        cost_usd_low: high / 4.0,
        cost_usd_high: high,
    }
}

#[test]
fn cap_pass_when_all_unlimited() {
    let cap = UserCostCap::default();
    let est = sample_estimate(5.0);
    assert_eq!(check_cap(&est, &cap, 0.0, 0.0), CapDecision::Pass);
}

#[test]
fn cap_blocks_when_single_task_exceeded() {
    let cap = UserCostCap {
        single_task_usd: Some(1.0),
        ..Default::default()
    };
    let est = sample_estimate(1.5);
    match check_cap(&est, &cap, 0.0, 0.0) {
        CapDecision::Block { kind, cap_amount, estimated } => {
            assert_eq!(kind, CapKind::SingleTask);
            assert!((cap_amount - 1.0).abs() < 1e-9);
            assert!((estimated - 1.5).abs() < 1e-9);
        }
        d => panic!("expected SingleTask block, got {d:?}"),
    }
}

#[test]
fn cap_blocks_when_monthly_would_exceed() {
    let cap = UserCostCap {
        monthly_usd: Some(10.0),
        ..Default::default()
    };
    let est = sample_estimate(2.0);
    match check_cap(&est, &cap, 9.0, 0.0) {
        CapDecision::Block { kind, .. } => assert_eq!(kind, CapKind::Monthly),
        d => panic!("expected Monthly block, got {d:?}"),
    }
}

#[test]
fn cap_blocks_when_per_server_would_exceed() {
    let cap = UserCostCap {
        per_server_usd: Some(5.0),
        ..Default::default()
    };
    let est = sample_estimate(2.0);
    match check_cap(&est, &cap, 0.0, 4.0) {
        CapDecision::Block { kind, .. } => assert_eq!(kind, CapKind::PerServer),
        d => panic!("expected PerServer block, got {d:?}"),
    }
}

#[test]
fn cap_single_task_checked_before_aggregates() {
    // Both caps would fire — single_task should win since it's
    // evaluated first (more specific/actionable feedback).
    let cap = UserCostCap {
        single_task_usd: Some(1.0),
        monthly_usd: Some(5.0),
        ..Default::default()
    };
    let est = sample_estimate(2.0);
    match check_cap(&est, &cap, 4.0, 0.0) {
        CapDecision::Block { kind, .. } => assert_eq!(kind, CapKind::SingleTask),
        d => panic!("expected SingleTask block, got {d:?}"),
    }
}

#[test]
fn cap_passes_at_exact_boundary() {
    // Boundary is strict-greater, so estimate == cap should pass.
    let cap = UserCostCap {
        single_task_usd: Some(1.0),
        ..Default::default()
    };
    let est = sample_estimate(1.0);
    assert_eq!(check_cap(&est, &cap, 0.0, 0.0), CapDecision::Pass);
}

// ── storage ─────────────────────────────────────────────────────────

#[test]
fn storage_insert_then_total_for_task() {
    let c = db();
    insert(
        &c,
        &rec(
            "r1",
            "t1",
            "s1",
            CostKind::PrimaryAiCall,
            "claude-3.5-sonnet",
            1_000,
            500,
            0.0105,
            "2026-05-01T00:00:00Z",
        ),
    )
    .unwrap();
    insert(
        &c,
        &rec(
            "r2",
            "t1",
            "s1",
            CostKind::ToolUse,
            "claude-3.5-sonnet",
            0,
            0,
            0.0,
            "2026-05-01T00:01:00Z",
        ),
    )
    .unwrap();
    let total = total_for_task(&c, "t1").unwrap();
    assert!((total - 0.0105).abs() < 1e-9);
}

#[test]
fn storage_insert_upsert_on_duplicate_id() {
    let c = db();
    let r = rec(
        "r1",
        "t1",
        "s1",
        CostKind::PrimaryAiCall,
        "claude-3.5-sonnet",
        1_000,
        500,
        0.01,
        "2026-05-01T00:00:00Z",
    );
    insert(&c, &r).unwrap();
    let mut r2 = r.clone();
    r2.cost_usd = 0.05;
    insert(&c, &r2).unwrap();
    let total = total_for_task(&c, "t1").unwrap();
    assert!((total - 0.05).abs() < 1e-9);
}

#[test]
fn storage_total_in_range_filters_by_ts() {
    let c = db();
    insert(
        &c,
        &rec(
            "old",
            "tA",
            "s1",
            CostKind::PrimaryAiCall,
            "claude-3.5-sonnet",
            0,
            0,
            1.0,
            "2026-04-30T23:59:59Z",
        ),
    )
    .unwrap();
    insert(
        &c,
        &rec(
            "new",
            "tB",
            "s1",
            CostKind::PrimaryAiCall,
            "claude-3.5-sonnet",
            0,
            0,
            2.5,
            "2026-05-01T00:00:00Z",
        ),
    )
    .unwrap();
    let v = total_in_range(&c, "2026-05-01T00:00:00Z", None).unwrap();
    assert!((v - 2.5).abs() < 1e-9);
}

#[test]
fn storage_total_in_range_scoped_to_server() {
    let c = db();
    insert(
        &c,
        &rec(
            "a",
            "tA",
            "s1",
            CostKind::PrimaryAiCall,
            "claude-3.5-sonnet",
            0,
            0,
            1.0,
            "2026-05-01T00:00:00Z",
        ),
    )
    .unwrap();
    insert(
        &c,
        &rec(
            "b",
            "tB",
            "s2",
            CostKind::PrimaryAiCall,
            "claude-3.5-sonnet",
            0,
            0,
            3.0,
            "2026-05-01T00:00:00Z",
        ),
    )
    .unwrap();
    let only_s2 = total_in_range(&c, "2026-05-01T00:00:00Z", Some("s2")).unwrap();
    assert!((only_s2 - 3.0).abs() < 1e-9);
}

#[test]
fn storage_summary_aggregates_across_dims() {
    let c = db();
    // Two tasks on s1, one on s2, mixed kinds.
    insert(
        &c,
        &rec(
            "1",
            "tA",
            "s1",
            CostKind::PrimaryAiCall,
            "claude-3.5-sonnet",
            1_000,
            500,
            0.05,
            "2026-05-10T00:00:00Z",
        ),
    )
    .unwrap();
    insert(
        &c,
        &rec(
            "2",
            "tA",
            "s1",
            CostKind::StreamingSummary,
            "claude-3-haiku",
            500,
            100,
            0.01,
            "2026-05-10T00:01:00Z",
        ),
    )
    .unwrap();
    insert(
        &c,
        &rec(
            "3",
            "tB",
            "s1",
            CostKind::PrimaryAiCall,
            "claude-3.5-sonnet",
            2_000,
            1_000,
            0.10,
            "2026-05-11T00:00:00Z",
        ),
    )
    .unwrap();
    insert(
        &c,
        &rec(
            "4",
            "tC",
            "s2",
            CostKind::PrimaryAiCall,
            "gpt-4o",
            3_000,
            1_500,
            0.20,
            "2026-05-12T00:00:00Z",
        ),
    )
    .unwrap();

    let sum = summary_since(&c, "2026-05-01T00:00:00Z", "This month", 5).unwrap();
    assert!((sum.total_usd - 0.36).abs() < 1e-9, "total {}", sum.total_usd);
    assert_eq!(sum.task_count, 3); // tA, tB, tC
    assert_eq!(sum.total_input_tokens, 6_500);
    assert_eq!(sum.total_output_tokens, 3_100);

    // by_server: s1 should aggregate to 0.16 over 2 tasks; s2 = 0.20 / 1.
    let s1 = sum.by_server.iter().find(|x| x.server_id == "s1").unwrap();
    let s2 = sum.by_server.iter().find(|x| x.server_id == "s2").unwrap();
    assert!((s1.cost_usd - 0.16).abs() < 1e-9);
    assert_eq!(s1.task_count, 2);
    assert!((s2.cost_usd - 0.20).abs() < 1e-9);
    assert_eq!(s2.task_count, 1);

    // top_tasks: tC = 0.20, tB = 0.10, tA = 0.06 — ordered descending.
    assert_eq!(sum.top_tasks[0].task_id, "tC");
    assert_eq!(sum.top_tasks[1].task_id, "tB");
    assert_eq!(sum.top_tasks[2].task_id, "tA");

    // by_kind: PrimaryAiCall dominates.
    let (top_kind, top_cost) = sum.by_kind[0];
    assert_eq!(top_kind, CostKind::PrimaryAiCall);
    assert!((top_cost - 0.35).abs() < 1e-9);
}

#[test]
fn storage_summary_top_n_caps_results() {
    let c = db();
    for i in 0..5 {
        insert(
            &c,
            &rec(
                &format!("r{i}"),
                &format!("t{i}"),
                "s1",
                CostKind::PrimaryAiCall,
                "claude-3.5-sonnet",
                0,
                0,
                (i + 1) as f64 * 0.1,
                "2026-05-10T00:00:00Z",
            ),
        )
        .unwrap();
    }
    let sum = summary_since(&c, "2026-05-01T00:00:00Z", "This month", 3).unwrap();
    assert_eq!(sum.top_tasks.len(), 3);
}

#[test]
fn storage_summary_empty_db_returns_zeros() {
    let c = db();
    let sum = summary_since(&c, "2026-05-01T00:00:00Z", "This month", 5).unwrap();
    assert_eq!(sum.total_usd, 0.0);
    assert_eq!(sum.task_count, 0);
    assert!(sum.by_server.is_empty());
    assert!(sum.top_tasks.is_empty());
}
