//! SQLite-backed CRUD for cost records.

use rusqlite::{params, Connection};

use super::{CostKind, CostRecord, CostSummary, ServerCostBreakdown, TaskCostBreakdown};

const SCHEMA_SQL: &str = r#"
CREATE TABLE IF NOT EXISTS task_costs (
    id              TEXT PRIMARY KEY,
    task_id         TEXT NOT NULL,
    server_id       TEXT NOT NULL,
    kind            TEXT NOT NULL,
    model           TEXT NOT NULL,
    input_tokens    INTEGER NOT NULL,
    output_tokens   INTEGER NOT NULL,
    cost_usd        REAL    NOT NULL,
    ts              TEXT    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_task_costs_task   ON task_costs(task_id);
CREATE INDEX IF NOT EXISTS idx_task_costs_server ON task_costs(server_id, ts);
CREATE INDEX IF NOT EXISTS idx_task_costs_ts     ON task_costs(ts);
"#;

pub fn ensure_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_SQL)
}

#[derive(Debug, thiserror::Error)]
pub enum CostError {
    #[error("sql: {0}")]
    Sql(#[from] rusqlite::Error),
}

pub fn insert(conn: &Connection, r: &CostRecord) -> Result<(), CostError> {
    conn.execute(
        "INSERT OR REPLACE INTO task_costs
            (id, task_id, server_id, kind, model, input_tokens, output_tokens, cost_usd, ts)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
        params![
            r.id,
            r.task_id,
            r.server_id,
            cost_kind_str(r.kind),
            r.model,
            r.input_tokens as i64,
            r.output_tokens as i64,
            r.cost_usd,
            r.ts,
        ],
    )?;
    Ok(())
}

/// Total cost for a task (sum across all kinds).
pub fn total_for_task(conn: &Connection, task_id: &str) -> Result<f64, CostError> {
    let v: f64 = conn.query_row(
        "SELECT COALESCE(SUM(cost_usd), 0.0) FROM task_costs WHERE task_id = ?1",
        params![task_id],
        |r| r.get(0),
    )?;
    Ok(v)
}

/// Total cost recorded in a (ts) range, optionally constrained to a
/// single server. Used by cap checks: pass `start_ts = "first of
/// month RFC3339"` to get the running monthly total.
pub fn total_in_range(
    conn: &Connection,
    start_ts: &str,
    server_id: Option<&str>,
) -> Result<f64, CostError> {
    let v: f64 = if let Some(s) = server_id {
        conn.query_row(
            "SELECT COALESCE(SUM(cost_usd), 0.0) FROM task_costs
             WHERE ts >= ?1 AND server_id = ?2",
            params![start_ts, s],
            |r| r.get(0),
        )?
    } else {
        conn.query_row(
            "SELECT COALESCE(SUM(cost_usd), 0.0) FROM task_costs WHERE ts >= ?1",
            params![start_ts],
            |r| r.get(0),
        )?
    };
    Ok(v)
}

/// Aggregate for the dashboard. `period_label` is a string the UI
/// renders verbatim ("This month" / "Last 30 days").
pub fn summary_since(
    conn: &Connection,
    start_ts: &str,
    period_label: impl Into<String>,
    top_n: usize,
) -> Result<CostSummary, CostError> {
    let total_usd: f64 = conn.query_row(
        "SELECT COALESCE(SUM(cost_usd), 0.0) FROM task_costs WHERE ts >= ?1",
        params![start_ts],
        |r| r.get(0),
    )?;
    let task_count: i64 = conn.query_row(
        "SELECT COUNT(DISTINCT task_id) FROM task_costs WHERE ts >= ?1",
        params![start_ts],
        |r| r.get(0),
    )?;
    let total_in: i64 = conn.query_row(
        "SELECT COALESCE(SUM(input_tokens), 0) FROM task_costs WHERE ts >= ?1",
        params![start_ts],
        |r| r.get(0),
    )?;
    let total_out: i64 = conn.query_row(
        "SELECT COALESCE(SUM(output_tokens), 0) FROM task_costs WHERE ts >= ?1",
        params![start_ts],
        |r| r.get(0),
    )?;

    let by_server = {
        let mut stmt = conn.prepare(
            "SELECT server_id, SUM(cost_usd) AS c, COUNT(DISTINCT task_id) AS n
             FROM task_costs WHERE ts >= ?1
             GROUP BY server_id ORDER BY c DESC",
        )?;
        let rows = stmt.query_map(params![start_ts], |r| {
            Ok(ServerCostBreakdown {
                server_id: r.get(0)?,
                cost_usd: r.get::<_, f64>(1)?,
                task_count: r.get::<_, i64>(2)? as u64,
            })
        })?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row?);
        }
        out
    };

    let top_tasks = {
        let mut stmt = conn.prepare(
            "SELECT task_id, SUM(cost_usd) AS c
             FROM task_costs WHERE ts >= ?1
             GROUP BY task_id ORDER BY c DESC LIMIT ?2",
        )?;
        let rows = stmt.query_map(params![start_ts, top_n as i64], |r| {
            Ok(TaskCostBreakdown {
                task_id: r.get(0)?,
                prompt_preview: String::new(),
                cost_usd: r.get::<_, f64>(1)?,
            })
        })?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row?);
        }
        out
    };

    let by_kind = {
        let mut stmt = conn.prepare(
            "SELECT kind, SUM(cost_usd) AS c
             FROM task_costs WHERE ts >= ?1
             GROUP BY kind ORDER BY c DESC",
        )?;
        let rows = stmt.query_map(params![start_ts], |r| {
            let k: String = r.get(0)?;
            let c: f64 = r.get(1)?;
            Ok((cost_kind_from_str(&k), c))
        })?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row?);
        }
        out
    };

    Ok(CostSummary {
        period_label: period_label.into(),
        total_usd,
        task_count: task_count as u64,
        total_input_tokens: total_in as u64,
        total_output_tokens: total_out as u64,
        by_server,
        top_tasks,
        by_kind,
    })
}

fn cost_kind_str(k: CostKind) -> &'static str {
    match k {
        CostKind::PrimaryAiCall => "primary_ai_call",
        CostKind::StreamingSummary => "streaming_summary",
        CostKind::ToolUse => "tool_use",
    }
}

fn cost_kind_from_str(s: &str) -> CostKind {
    match s {
        "streaming_summary" => CostKind::StreamingSummary,
        "tool_use" => CostKind::ToolUse,
        _ => CostKind::PrimaryAiCall,
    }
}
