//! SQLite CRUD for the `task_metrics` table. The daemon DB layer
//! pulls `ensure_schema` in at startup via migration #30; tests use
//! it directly against an in-memory connection.

use rusqlite::{params, Connection, OptionalExtension};

use super::{ReliabilityError, TaskMetrics};

const SCHEMA_SQL: &str = r#"
CREATE TABLE IF NOT EXISTS task_metrics (
    task_id           TEXT PRIMARY KEY,
    ws_uptime_ms      INTEGER NOT NULL DEFAULT 0,
    reconnect_count   INTEGER NOT NULL DEFAULT 0,
    bg_duration_ms    INTEGER NOT NULL DEFAULT 0,
    push_latency_ms   INTEGER,
    handoff_count     INTEGER NOT NULL DEFAULT 0,
    updated_at        TEXT    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_task_metrics_updated ON task_metrics(updated_at);
"#;

pub fn ensure_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_SQL)
}

/// Insert-or-replace. The Flutter ReliabilityMetricsProvider always
/// reads-then-writes the full row so an UPSERT is the natural fit
/// — no per-field UPDATE queries to maintain.
pub fn save(conn: &Connection, m: &TaskMetrics) -> Result<(), ReliabilityError> {
    conn.execute(
        "INSERT OR REPLACE INTO task_metrics
            (task_id, ws_uptime_ms, reconnect_count, bg_duration_ms,
             push_latency_ms, handoff_count, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
        params![
            m.task_id,
            m.ws_uptime_ms as i64,
            m.reconnect_count as i64,
            m.bg_duration_ms as i64,
            m.push_latency_ms.map(|v| v as i64),
            m.handoff_count as i64,
            m.updated_at,
        ],
    )?;
    Ok(())
}

pub fn get(conn: &Connection, task_id: &str) -> Result<Option<TaskMetrics>, ReliabilityError> {
    let row = conn
        .query_row(
            "SELECT task_id, ws_uptime_ms, reconnect_count, bg_duration_ms,
                    push_latency_ms, handoff_count, updated_at
             FROM task_metrics WHERE task_id = ?1",
            params![task_id],
            row_to_metrics,
        )
        .optional()?;
    Ok(row)
}

pub fn delete(conn: &Connection, task_id: &str) -> Result<(), ReliabilityError> {
    conn.execute(
        "DELETE FROM task_metrics WHERE task_id = ?1",
        params![task_id],
    )?;
    Ok(())
}

/// All metrics rows, most-recently-updated first. Used by the dev
/// mode "all task health" panel.
pub fn list(conn: &Connection) -> Result<Vec<TaskMetrics>, ReliabilityError> {
    let mut stmt = conn.prepare(
        "SELECT task_id, ws_uptime_ms, reconnect_count, bg_duration_ms,
                push_latency_ms, handoff_count, updated_at
         FROM task_metrics ORDER BY updated_at DESC",
    )?;
    let rows = stmt.query_map([], row_to_metrics)?;
    let mut out = Vec::new();
    for r in rows {
        out.push(r?);
    }
    Ok(out)
}

fn row_to_metrics(row: &rusqlite::Row) -> rusqlite::Result<TaskMetrics> {
    Ok(TaskMetrics {
        task_id: row.get(0)?,
        ws_uptime_ms: row.get::<_, i64>(1)? as u64,
        reconnect_count: row.get::<_, i64>(2)? as u32,
        bg_duration_ms: row.get::<_, i64>(3)? as u64,
        push_latency_ms: row.get::<_, Option<i64>>(4)?.map(|v| v as u32),
        handoff_count: row.get::<_, i64>(5)? as u32,
        updated_at: row.get(6)?,
    })
}
