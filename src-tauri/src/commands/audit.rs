use tauri::State;
use crate::state::AppState;

/// Lists audit log entries with optional filtering, date range, and pagination.
#[tauri::command]
pub fn audit_log_list(
    state: State<'_, AppState>,
    event_type: Option<String>,
    start_date: Option<String>,
    end_date: Option<String>,
    limit: Option<u32>,
    offset: Option<u32>,
) -> Result<serde_json::Value, String> {
    let limit = limit.unwrap_or(50).min(200);
    let offset = offset.unwrap_or(0);

    state.db.with_conn(|conn| {
        let mut conditions: Vec<String> = Vec::new();
        let mut params_vec: Vec<Box<dyn rusqlite::types::ToSql>> = Vec::new();
        let mut param_idx = 1u32;

        if let Some(ref et) = event_type {
            conditions.push(format!("event_type = ?{param_idx}"));
            params_vec.push(Box::new(et.clone()));
            param_idx += 1;
        }
        if let Some(ref sd) = start_date {
            conditions.push(format!("timestamp >= ?{param_idx}"));
            params_vec.push(Box::new(sd.clone()));
            param_idx += 1;
        }
        if let Some(ref ed) = end_date {
            conditions.push(format!("timestamp <= ?{param_idx}"));
            params_vec.push(Box::new(ed.clone()));
            param_idx += 1;
        }

        let where_clause = if conditions.is_empty() {
            String::new()
        } else {
            format!(" WHERE {}", conditions.join(" AND "))
        };

        let sql = format!(
            "SELECT id, timestamp, event_type, detail FROM audit_log{where_clause} ORDER BY id DESC LIMIT ?{} OFFSET ?{}",
            param_idx,
            param_idx + 1,
        );
        params_vec.push(Box::new(limit));
        params_vec.push(Box::new(offset));

        let params_refs: Vec<&dyn rusqlite::types::ToSql> = params_vec.iter().map(|p| p.as_ref()).collect();
        let mut stmt = conn.prepare(&sql)?;
        let rows: Vec<serde_json::Value> = stmt
            .query_map(params_refs.as_slice(), |row| {
                Ok(serde_json::json!({
                    "id": row.get::<_, i64>(0)?,
                    "timestamp": row.get::<_, String>(1)?,
                    "eventType": row.get::<_, String>(2)?,
                    "detail": row.get::<_, Option<String>>(3)?,
                }))
            })?
            .filter_map(|r| r.ok())
            .collect();

        let count_sql = format!("SELECT COUNT(*) FROM audit_log{where_clause}");
        let count_params: Vec<&dyn rusqlite::types::ToSql> = params_refs[..params_refs.len() - 2].to_vec();
        let total: i64 = conn.query_row(&count_sql, count_params.as_slice(), |row| row.get(0))?;

        Ok(serde_json::json!({
            "items": rows,
            "total": total,
            "page": offset / limit + 1,
            "pageSize": limit,
        }))
    }).map_err(|e| e.to_string())
}

/// Returns summary counts for audit dashboard.
#[tauri::command]
pub fn audit_log_summary(
    state: State<'_, AppState>,
    start_date: Option<String>,
    end_date: Option<String>,
) -> Result<serde_json::Value, String> {
    state.db.with_conn(|conn| {
        let mut conditions: Vec<String> = Vec::new();
        let mut params_vec: Vec<Box<dyn rusqlite::types::ToSql>> = Vec::new();
        let mut param_idx = 1u32;

        if let Some(ref sd) = start_date {
            conditions.push(format!("timestamp >= ?{param_idx}"));
            params_vec.push(Box::new(sd.clone()));
            param_idx += 1;
        }
        if let Some(ref ed) = end_date {
            conditions.push(format!("timestamp <= ?{param_idx}"));
            params_vec.push(Box::new(ed.clone()));
        }

        let where_clause = if conditions.is_empty() {
            String::new()
        } else {
            format!(" WHERE {}", conditions.join(" AND "))
        };

        let count_sql = format!(
            "SELECT event_type, COUNT(*) as cnt FROM audit_log{where_clause} GROUP BY event_type"
        );
        let params_refs: Vec<&dyn rusqlite::types::ToSql> = params_vec.iter().map(|p| p.as_ref()).collect();
        let mut stmt = conn.prepare(&count_sql)?;
        let mut counts = serde_json::Map::new();
        let mut total = 0i64;

        stmt.query_map(params_refs.as_slice(), |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)?))
        })?
        .filter_map(|r| r.ok())
        .for_each(|(et, cnt)| {
            total += cnt;
            counts.insert(et, serde_json::Value::Number(cnt.into()));
        });

        // Aggregate into categories
        let connections = ["ssh_connect_success", "ssh_connect_attempt", "ssh_connect_failed", "ssh_disconnect"]
            .iter()
            .map(|k| counts.get(*k).and_then(|v| v.as_i64()).unwrap_or(0))
            .sum::<i64>();

        let cred_access = counts.get("credential_accessed").and_then(|v| v.as_i64()).unwrap_or(0);

        let config_changes = ["server_created", "server_deleted", "config_exported", "config_imported"]
            .iter()
            .map(|k| counts.get(*k).and_then(|v| v.as_i64()).unwrap_or(0))
            .sum::<i64>();

        let member_ops = ["team_member_role_change", "team_member_remove", "team_create", "team_join", "team_leave", "team_key_rotated"]
            .iter()
            .map(|k| counts.get(*k).and_then(|v| v.as_i64()).unwrap_or(0))
            .sum::<i64>();

        Ok(serde_json::json!({
            "total": total,
            "connections": connections,
            "credentialAccess": cred_access,
            "configChanges": config_changes,
            "memberOps": member_ops,
            "byType": counts,
        }))
    }).map_err(|e| e.to_string())
}

/// Exports audit log entries to a file (JSON, CSV, or HTML).
#[tauri::command]
pub fn audit_export_report(
    state: State<'_, AppState>,
    file_path: String,
    start_date: String,
    end_date: String,
    event_types: Option<Vec<String>>,
    format: String,
) -> Result<(), String> {
    let entries = state.db.with_conn(|conn| {
        let mut conditions = vec!["timestamp >= ?1".to_string(), "timestamp <= ?2".to_string()];
        let mut params_vec: Vec<Box<dyn rusqlite::types::ToSql>> = vec![
            Box::new(start_date.clone()),
            Box::new(end_date.clone()),
        ];

        if let Some(ref types) = event_types {
            if !types.is_empty() {
                let placeholders: Vec<String> = types.iter().enumerate()
                    .map(|(i, _)| format!("?{}", i + 3))
                    .collect();
                conditions.push(format!("event_type IN ({})", placeholders.join(",")));
                for t in types {
                    params_vec.push(Box::new(t.clone()));
                }
            }
        }

        let sql = format!(
            "SELECT id, timestamp, event_type, detail FROM audit_log WHERE {} ORDER BY timestamp ASC",
            conditions.join(" AND ")
        );
        let params_refs: Vec<&dyn rusqlite::types::ToSql> = params_vec.iter().map(|p| p.as_ref()).collect();
        let mut stmt = conn.prepare(&sql)?;
        let rows: Vec<(i64, String, String, Option<String>)> = stmt
            .query_map(params_refs.as_slice(), |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, Option<String>>(3)?,
                ))
            })?
            .filter_map(|r| r.ok())
            .collect();
        Ok(rows)
    }).map_err(|e| e.to_string())?;

    let content = match format.as_str() {
        "csv" => render_csv(&entries),
        "html" => render_html(&entries, &start_date, &end_date),
        _ => render_json(&entries),
    };

    std::fs::write(&file_path, content).map_err(|e| e.to_string())?;
    Ok(())
}

fn render_json(entries: &[(i64, String, String, Option<String>)]) -> String {
    let items: Vec<serde_json::Value> = entries.iter().map(|(id, ts, et, detail)| {
        serde_json::json!({
            "id": id,
            "timestamp": ts,
            "eventType": et,
            "detail": detail,
        })
    }).collect();
    serde_json::to_string_pretty(&items).unwrap_or_default()
}

fn render_csv(entries: &[(i64, String, String, Option<String>)]) -> String {
    let mut out = String::from("ID,Timestamp,Event Type,Detail\n");
    for (id, ts, et, detail) in entries {
        let d = detail.as_deref().unwrap_or("").replace('"', "\"\"");
        out.push_str(&format!("{id},{ts},{et},\"{d}\"\n"));
    }
    out
}

fn render_html(entries: &[(i64, String, String, Option<String>)], start: &str, end: &str) -> String {
    let mut html = format!(
        r#"<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Termex Audit Report</title>
<style>
body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 960px; margin: 0 auto; padding: 20px; }}
h1 {{ font-size: 18px; }} h2 {{ font-size: 14px; margin-top: 24px; }}
table {{ border-collapse: collapse; width: 100%; font-size: 12px; }}
th, td {{ border: 1px solid #ddd; padding: 6px 8px; text-align: left; }}
th {{ background: #f5f5f5; }} .summary {{ display: flex; gap: 16px; margin: 16px 0; }}
.card {{ padding: 12px 16px; border: 1px solid #ddd; border-radius: 4px; text-align: center; }}
.card .num {{ font-size: 24px; font-weight: bold; }} .card .label {{ font-size: 11px; color: #888; }}
</style></head><body>
<h1>Termex Audit Report</h1>
<p>Period: {start} &mdash; {end} &middot; Total: {total} events</p>
<h2>Timeline</h2>
<table><tr><th>Timestamp</th><th>Event</th><th>Detail</th></tr>"#,
        total = entries.len()
    );

    for (_, ts, et, detail) in entries {
        let d = detail.as_deref().unwrap_or("-");
        html.push_str(&format!("<tr><td>{ts}</td><td>{et}</td><td>{d}</td></tr>\n"));
    }
    html.push_str("</table></body></html>");
    html
}

/// Clears audit log entries older than the configured retention period.
#[tauri::command]
pub fn audit_log_cleanup(
    state: State<'_, AppState>,
    retention_days: Option<i64>,
) -> Result<(), String> {
    crate::audit::cleanup(&state.db, retention_days.unwrap_or(90));
    Ok(())
}
