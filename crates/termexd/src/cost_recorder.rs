//! v0.74.1 daemon-side cost recorder.
//!
//! Bridges MCP `usage` notifications (input/output tokens + model)
//! into rows in the daemon DB's `task_costs` table. Decoupled from
//! the MCP adapter so the supervisor can call it directly without
//! reaching into the wire-format layer.
//!
//! Pricing comes from `termex_core::cost::pricing::ModelPricing`'s
//! default table — overrides live client-side and apply at
//! presentation time, so the daemon records the canonical estimate
//! (what a user with no overrides would see).

use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use tokio::sync::Mutex;
use tracing::{debug, warn};
use uuid::Uuid;

use termex_core::cost::pricing::ModelPricing;
use termex_core::cost::storage as cost_storage;
use termex_core::cost::{CostKind, CostRecord};

use crate::db::Database;

#[derive(Clone)]
pub struct CostRecorder {
    db: Arc<Mutex<Database>>,
    pricing: Arc<ModelPricing>,
}

impl CostRecorder {
    pub fn new(db: Arc<Mutex<Database>>) -> Self {
        Self {
            db,
            pricing: Arc::new(ModelPricing::default()),
        }
    }

    /// Record an MCP usage notification as a row in `task_costs`.
    /// `server_id` is the SSH server the task is running against —
    /// when the daemon doesn't track that (single-machine deploy)
    /// pass `""` and the per-server breakdown collapses to a single
    /// bucket in the dashboard.
    pub async fn record_usage(
        &self,
        task_id: &str,
        server_id: &str,
        kind: CostKind,
        model: &str,
        input_tokens: u64,
        output_tokens: u64,
    ) {
        let cost = self.pricing.calculate(model, input_tokens, output_tokens);
        let record = CostRecord {
            id: Uuid::new_v4().to_string(),
            task_id: task_id.to_string(),
            server_id: server_id.to_string(),
            kind,
            model: model.to_string(),
            input_tokens,
            output_tokens,
            cost_usd: cost,
            ts: now_rfc3339(),
        };
        let db = self.db.lock().await;
        let conn = db.conn();
        if let Err(e) = cost_storage::ensure_schema(conn) {
            warn!(error = %e, "cost_recorder: ensure_schema failed");
            return;
        }
        match cost_storage::insert(conn, &record) {
            Ok(()) => debug!(
                task = %task_id,
                model = %model,
                cost_usd = cost,
                "cost: recorded usage"
            ),
            Err(e) => warn!(error = %e, "cost_recorder: insert failed"),
        }
    }

    /// Total recorded cost for a task — convenience for the
    /// supervisor's task-complete summary.
    pub async fn total_for_task(&self, task_id: &str) -> f64 {
        let db = self.db.lock().await;
        let conn = db.conn();
        if cost_storage::ensure_schema(conn).is_err() {
            return 0.0;
        }
        cost_storage::total_for_task(conn, task_id).unwrap_or(0.0)
    }
}

fn now_rfc3339() -> String {
    let _ = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs());
    chrono::Utc::now().to_rfc3339()
}
