//! FRB bridge for the v0.74.1 cost tracker.
//!
//! Thin wrappers over `termex_core::cost::{pricing, estimator,
//! storage}` so Flutter widgets (CostChip, CostDashboard, CostCapDialog)
//! can call into the client-side cost store + estimator without
//! re-implementing pricing tables in Dart.

use serde::{Deserialize, Serialize};

use termex_core::cost::estimator::{
    check_cap as core_check_cap, estimate_task_cost as core_estimate_task_cost,
};
use termex_core::cost::pricing::ModelPricing;
use termex_core::cost::storage as cost_storage;
use termex_core::cost::{CapDecision, CapKind, CostKind, CostRecord, CostSummary, UserCostCap};
use termex_core::task::AiCliKind;

use crate::db_state;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CostEstimateDto {
    pub model: String,
    pub input_tokens_est: u64,
    pub output_tokens_est: u64,
    pub cost_usd_low: f64,
    pub cost_usd_high: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CapCheckDto {
    pub blocked: bool,
    /// "monthly" / "single_task" / "per_server" — empty when not blocked.
    pub kind: String,
    pub cap_amount: f64,
    pub estimated: f64,
}

/// Pre-flight cost estimate. Uses default pricing table; user
/// overrides live in settings and are layered in a follow-up.
pub fn cost_estimate(
    ai_cli: String,
    prompt: String,
    historical_avg_output_tokens: Option<u64>,
) -> Result<CostEstimateDto, String> {
    let cli = parse_cli(&ai_cli)?;
    let pricing = ModelPricing::default();
    let e = core_estimate_task_cost(cli, &prompt, historical_avg_output_tokens, &pricing);
    Ok(CostEstimateDto {
        model: e.model,
        input_tokens_est: e.input_tokens_est,
        output_tokens_est: e.output_tokens_est,
        cost_usd_low: e.cost_usd_low,
        cost_usd_high: e.cost_usd_high,
    })
}

/// Check whether `estimate_high_usd` would breach any user cap given
/// the current period totals.
pub fn cost_check_cap(
    estimate_high_usd: f64,
    monthly_cap_usd: Option<f64>,
    single_task_cap_usd: Option<f64>,
    per_server_cap_usd: Option<f64>,
    current_month_total_usd: f64,
    current_server_total_usd: f64,
) -> Result<CapCheckDto, String> {
    let est = termex_core::cost::estimator::CostEstimate {
        model: String::new(),
        input_tokens_est: 0,
        output_tokens_est: 0,
        cost_usd_low: estimate_high_usd / 4.0,
        cost_usd_high: estimate_high_usd,
    };
    let cap = UserCostCap {
        monthly_usd: monthly_cap_usd,
        single_task_usd: single_task_cap_usd,
        per_server_usd: per_server_cap_usd,
    };
    let decision = core_check_cap(
        &est,
        &cap,
        current_month_total_usd,
        current_server_total_usd,
    );
    Ok(match decision {
        CapDecision::Pass => CapCheckDto {
            blocked: false,
            kind: String::new(),
            cap_amount: 0.0,
            estimated: estimate_high_usd,
        },
        CapDecision::Block {
            kind,
            cap_amount,
            estimated,
        } => CapCheckDto {
            blocked: true,
            kind: cap_kind_str(kind).to_string(),
            cap_amount,
            estimated,
        },
    })
}

/// Persist a finished call's actual cost.
pub fn cost_record(
    id: String,
    task_id: String,
    server_id: String,
    kind: String,
    model: String,
    input_tokens: u64,
    output_tokens: u64,
    cost_usd: f64,
    ts: String,
) -> Result<(), String> {
    let rec = CostRecord {
        id,
        task_id,
        server_id,
        kind: parse_kind(&kind)?,
        model,
        input_tokens,
        output_tokens,
        cost_usd,
        ts,
    };
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            cost_storage::insert(conn, &rec).map_err(|e| {
                rusqlite::Error::ToSqlConversionFailure(Box::new(std::io::Error::other(
                    e.to_string(),
                )))
            })
        })
        .map_err(|e| e.to_string())
    })
}

/// Sum of all costs charged against `task_id`.
pub fn cost_total_for_task(task_id: String) -> Result<f64, String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            cost_storage::total_for_task(conn, &task_id).map_err(|e| {
                rusqlite::Error::ToSqlConversionFailure(Box::new(std::io::Error::other(
                    e.to_string(),
                )))
            })
        })
        .map_err(|e| e.to_string())
    })
}

/// Aggregate for the dashboard.
pub fn cost_summary(
    start_ts: String,
    period_label: String,
    top_n: u32,
) -> Result<CostSummary, String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            cost_storage::summary_since(conn, &start_ts, period_label, top_n as usize).map_err(
                |e| {
                    rusqlite::Error::ToSqlConversionFailure(Box::new(std::io::Error::other(
                        e.to_string(),
                    )))
                },
            )
        })
        .map_err(|e| e.to_string())
    })
}

fn parse_cli(s: &str) -> Result<AiCliKind, String> {
    match s {
        "claude_code" => Ok(AiCliKind::ClaudeCode),
        "codex" => Ok(AiCliKind::Codex),
        "aider" => Ok(AiCliKind::Aider),
        "generic" => Ok(AiCliKind::Generic),
        other => Err(format!("unknown ai_cli kind: {other}")),
    }
}

fn parse_kind(s: &str) -> Result<CostKind, String> {
    match s {
        "primary_ai_call" => Ok(CostKind::PrimaryAiCall),
        "streaming_summary" => Ok(CostKind::StreamingSummary),
        "tool_use" => Ok(CostKind::ToolUse),
        other => Err(format!("unknown cost kind: {other}")),
    }
}

fn cap_kind_str(k: CapKind) -> &'static str {
    match k {
        CapKind::Monthly => "monthly",
        CapKind::SingleTask => "single_task",
        CapKind::PerServer => "per_server",
    }
}
