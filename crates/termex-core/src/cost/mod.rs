//! Cost tracking — token-usage records, pricing lookup, and the
//! "would this task push us past a cap?" estimator.
//!
//! v0.74.1 ships the data model + business logic. Wire-level
//! integration with `termexd` (recording MCP usage events into the
//! task_costs table) and Flutter UI (CostDashboard, CostCap dialog)
//! plug in on top of these primitives.

pub mod estimator;
pub mod pricing;
pub mod storage;

use serde::{Deserialize, Serialize};

/// Where a cost row came from. Cards can render different chip
/// colors per kind so users see where the spend went.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CostKind {
    /// The main AI CLI invocation (Claude Code / Codex / Aider).
    PrimaryAiCall,

    /// The live-summary LLM call v0.73.0 makes against the
    /// rolling stdout to update the AI summary panel.
    StreamingSummary,

    /// Tool calls the AI CLI made on the user's behalf — typically
    /// $0 (free MCP) but tracked so we can credit per-tool cost
    /// when a future MCP server reports usage.
    ToolUse,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CostRecord {
    /// uuid v4 — unique per LLM call.
    pub id: String,
    pub task_id: String,
    pub server_id: String,
    pub kind: CostKind,
    pub model: String,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cost_usd: f64,
    pub ts: String, // RFC3339
}

/// Aggregated view for the dashboard.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CostSummary {
    pub period_label: String,
    pub total_usd: f64,
    pub task_count: u64,
    pub total_input_tokens: u64,
    pub total_output_tokens: u64,
    pub by_server: Vec<ServerCostBreakdown>,
    pub top_tasks: Vec<TaskCostBreakdown>,
    pub by_kind: Vec<(CostKind, f64)>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ServerCostBreakdown {
    pub server_id: String,
    pub cost_usd: f64,
    pub task_count: u64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TaskCostBreakdown {
    pub task_id: String,
    pub prompt_preview: String,
    pub cost_usd: f64,
}

/// User-configurable spending limits. None = unlimited.
#[derive(Debug, Clone, Copy, Default, PartialEq, Serialize, Deserialize)]
pub struct UserCostCap {
    pub monthly_usd: Option<f64>,
    pub single_task_usd: Option<f64>,
    pub per_server_usd: Option<f64>,
}

/// Outcome of evaluating an [`UserCostCap`] against a fresh
/// [`CostEstimate`] given the current period totals.
#[derive(Debug, Clone, PartialEq)]
pub enum CapDecision {
    Pass,
    Block {
        kind: CapKind,
        cap_amount: f64,
        estimated: f64,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CapKind {
    Monthly,
    SingleTask,
    PerServer,
}
