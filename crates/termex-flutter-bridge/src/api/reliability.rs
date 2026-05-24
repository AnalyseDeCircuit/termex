//! FRB bridge for the v0.75.0 reliability metrics. Read/write
//! wrappers over `termex_core::reliability::storage` so the Flutter
//! ReliabilityMetricsProvider can persist counter updates without
//! caring about SQLite.

use termex_core::reliability::metrics;
use termex_core::reliability::storage as rel_storage;
use termex_core::reliability::TaskMetrics;

use crate::db_state;

/// Get the current snapshot — `None` when no metrics row exists
/// for this task yet (caller defaults to TaskMetrics::empty).
pub fn reliability_get(task_id: String) -> Result<Option<TaskMetrics>, String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| rel_storage::get(conn, &task_id).map_err(sql_box))
            .map_err(|e| e.to_string())
    })
}

pub fn reliability_save(m: TaskMetrics) -> Result<(), String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| rel_storage::save(conn, &m).map_err(sql_box))
            .map_err(|e| e.to_string())
    })
}

pub fn reliability_delete(task_id: String) -> Result<(), String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| rel_storage::delete(conn, &task_id).map_err(sql_box))
            .map_err(|e| e.to_string())
    })
}

pub fn reliability_list() -> Result<Vec<TaskMetrics>, String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| rel_storage::list(conn).map_err(sql_box))
            .map_err(|e| e.to_string())
    })
}

// ─── increment helpers ─────────────────────────────────────────────
// Each does a read-modify-write so the Dart side doesn't need to
// shuttle the full TaskMetrics for a simple counter bump.

pub fn reliability_record_reconnect(task_id: String, now_rfc3339: String) -> Result<(), String> {
    write_helper(task_id, now_rfc3339, |m, now| {
        metrics::record_reconnect(m, now)
    })
}

pub fn reliability_record_ws_session(
    task_id: String,
    duration_ms: u64,
    now_rfc3339: String,
) -> Result<(), String> {
    write_helper(task_id, now_rfc3339, |m, now| {
        metrics::record_ws_session(m, duration_ms, now)
    })
}

pub fn reliability_record_bg_duration(
    task_id: String,
    duration_ms: u64,
    now_rfc3339: String,
) -> Result<(), String> {
    write_helper(task_id, now_rfc3339, |m, now| {
        metrics::record_bg_duration(m, duration_ms, now)
    })
}

pub fn reliability_record_push_latency(
    task_id: String,
    latency_ms: u32,
    now_rfc3339: String,
) -> Result<(), String> {
    write_helper(task_id, now_rfc3339, |m, now| {
        metrics::record_push_latency(m, latency_ms, now)
    })
}

pub fn reliability_record_handoff(task_id: String, now_rfc3339: String) -> Result<(), String> {
    write_helper(task_id, now_rfc3339, |m, now| metrics::record_handoff(m, now))
}

fn write_helper<F>(task_id: String, now_rfc3339: String, mutate: F) -> Result<(), String>
where
    F: FnOnce(&TaskMetrics, &str) -> TaskMetrics,
{
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let current = rel_storage::get(conn, &task_id)
                .map_err(sql_box)?
                .unwrap_or_else(|| TaskMetrics::empty(task_id.clone(), now_rfc3339.clone()));
            let next = mutate(&current, &now_rfc3339);
            rel_storage::save(conn, &next).map_err(sql_box)
        })
        .map_err(|e| e.to_string())
    })
}

fn sql_box(e: termex_core::reliability::ReliabilityError) -> rusqlite::Error {
    rusqlite::Error::ToSqlConversionFailure(Box::new(std::io::Error::other(e.to_string())))
}
