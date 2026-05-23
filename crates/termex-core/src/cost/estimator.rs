//! Pre-execution cost estimate + cap evaluator.
//!
//! `estimate_task_cost` produces a low/high range so the UI can
//! show "$0.001–$0.012 (claude-3.5-sonnet)" without overstating
//! precision. `check_cap` returns a typed [`CapDecision`] used by
//! termexd's risk gate to pause tasks that would push past a
//! configured limit.

use crate::task::AiCliKind;

use super::pricing::ModelPricing;
use super::{CapDecision, CapKind, UserCostCap};

/// Pre-flight estimate. `low` assumes the AI replies with half its
/// historical average output length; `high` assumes 2x.
#[derive(Debug, Clone, PartialEq)]
pub struct CostEstimate {
    pub model: String,
    pub input_tokens_est: u64,
    pub output_tokens_est: u64,
    pub cost_usd_low: f64,
    pub cost_usd_high: f64,
}

/// Default model + tokens-per-character ratio per CLI. Roughly 4
/// chars per token for English; the estimator's job is "ball-park
/// before clicking submit", not "billing accurate".
const CHARS_PER_TOKEN: usize = 4;

pub fn estimate_task_cost(
    ai_cli: AiCliKind,
    prompt: &str,
    historical_avg_output_tokens: Option<u64>,
    pricing: &ModelPricing,
) -> CostEstimate {
    let model = default_model_for(ai_cli).to_string();
    let input_tokens_est = ((prompt.chars().count() + CHARS_PER_TOKEN - 1) / CHARS_PER_TOKEN) as u64;
    let output_tokens_est = historical_avg_output_tokens.unwrap_or(2_000);
    let low = pricing.calculate(&model, input_tokens_est, output_tokens_est / 2);
    let high = pricing.calculate(&model, input_tokens_est, output_tokens_est * 2);
    CostEstimate {
        model,
        input_tokens_est,
        output_tokens_est,
        cost_usd_low: low,
        cost_usd_high: high,
    }
}

/// Default model name passed to pricing lookup per AI CLI kind.
/// Mirrors what the v0.71.1 supervisor actually invokes — keeping
/// the estimator + the recorder aligned avoids surprise overage.
fn default_model_for(ai_cli: AiCliKind) -> &'static str {
    match ai_cli {
        AiCliKind::ClaudeCode => "claude-3.5-sonnet",
        AiCliKind::Codex => "gpt-4o",
        AiCliKind::Aider => "claude-3.5-sonnet",
        AiCliKind::Generic => "claude-3-haiku",
    }
}

/// Decide whether to block, given the user's caps + accumulated
/// monthly / per-server spend. Uses `cost_usd_high` (worst case) so
/// the user opts in to risk rather than is surprised by it.
pub fn check_cap(
    estimate: &CostEstimate,
    cap: &UserCostCap,
    current_month_total_usd: f64,
    current_server_total_usd: f64,
) -> CapDecision {
    if let Some(single) = cap.single_task_usd {
        if estimate.cost_usd_high > single {
            return CapDecision::Block {
                kind: CapKind::SingleTask,
                cap_amount: single,
                estimated: estimate.cost_usd_high,
            };
        }
    }
    if let Some(monthly) = cap.monthly_usd {
        if current_month_total_usd + estimate.cost_usd_high > monthly {
            return CapDecision::Block {
                kind: CapKind::Monthly,
                cap_amount: monthly,
                estimated: estimate.cost_usd_high,
            };
        }
    }
    if let Some(per_server) = cap.per_server_usd {
        if current_server_total_usd + estimate.cost_usd_high > per_server {
            return CapDecision::Block {
                kind: CapKind::PerServer,
                cap_amount: per_server,
                estimated: estimate.cost_usd_high,
            };
        }
    }
    CapDecision::Pass
}
