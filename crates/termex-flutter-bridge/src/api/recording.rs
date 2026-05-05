/// Session recording management exposed to Flutter via FRB (v0.47 spec §5).
///
/// Metadata persists to the `recordings` table (V13 + V17 team columns + V23
/// encryption/part_linkage).  The actual `.cast` file is stored on the
/// filesystem under `{app_data_dir}/recordings/`.
///
/// When the database is not unlocked the API falls back to a process-local
/// in-memory registry so UI flows can be exercised in unit tests without a DB.
use std::collections::HashMap;
use std::sync::Mutex;

use once_cell::sync::Lazy;

use crate::db_state;

// ─── DTOs ────────────────────────────────────────────────────────────────────

/// Full recording metadata (v0.47 spec §9.5.2).
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RecordingDto {
    pub id: String,
    pub session_id: String,
    pub server_id: String,
    pub server_name: String,
    pub file_path: String,
    pub file_size: u64,
    pub duration_ms: u64,
    pub cols: u16,
    pub rows: u16,
    pub event_count: u32,
    pub summary: Option<String>,
    pub auto_recorded: bool,
    pub started_at: String,
    pub ended_at: Option<String>,
    pub parent_id: Option<String>,
    pub is_encrypted: bool,
}

/// Legacy simpler DTO for v0.46-era Dart tests.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RecordingEntry {
    pub id: String,
    pub session_id: String,
    pub title: Option<String>,
    pub file_path: String,
    pub duration_seconds: u64,
    pub size_bytes: u64,
    pub created_at: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AsciicastHeader {
    pub version: u16,
    pub width: u16,
    pub height: u16,
    pub timestamp: u64,
    pub title: Option<String>,
    pub env: HashMap<String, String>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CastEvent {
    pub relative_time: f64,
    pub kind: String,
    pub data: String,
}

// ─── Registry (in-memory fallback) ──────────────────────────────────────────

static RECORDING_REGISTRY: Lazy<Mutex<HashMap<String, RecordingEntry>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

// ─── Filename rendering (§5.5) ──────────────────────────────────────────────

fn sanitize_server_name(name: &str) -> String {
    name.chars()
        .map(|c| if c.is_ascii_alphanumeric() || c == '-' || c == '_' { c } else { '_' })
        .collect()
}

fn random_hex6() -> String {
    use ring::rand::{SecureRandom, SystemRandom};
    let rng = SystemRandom::new();
    let mut bytes = [0u8; 3];
    let _ = rng.fill(&mut bytes);
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}

/// Renders the canonical `.cast` filename for a new recording.
pub fn recording_render_filename(server_name: &str) -> String {
    let safe = sanitize_server_name(server_name);
    let ts = chrono::Utc::now().format("%Y%m%dT%H%M%S");
    let rand = random_hex6();
    format!("{}_{}_{}.cast", safe, ts, rand)
}

/// Renders the filename for an auto-split part (part2+).
pub fn recording_render_part_filename(basename: &str, part_n: u32) -> String {
    let trimmed = basename.trim_end_matches(".cast");
    format!("{}_part{}.cast", trimmed, part_n)
}

// ─── Core API ───────────────────────────────────────────────────────────────

/// Begins recording terminal output for `session_id`.  Returns a new recording id.
pub fn recording_start(session_id: String, title: Option<String>) -> Result<String, String> {
    let id = uuid::Uuid::new_v4().to_string();
    let filename = recording_render_filename(title.as_deref().unwrap_or("session"));
    let file_path = format!("/tmp/{}", filename); // Final path set by core::recording

    if db_state::is_unlocked() {
        db_state::with_db(|db| {
            db.with_conn(|conn| {
                let now = chrono::Utc::now().to_rfc3339();
                conn.execute(
                    "INSERT INTO recordings
                       (id, session_id, server_id, server_name, file_path, file_size,
                        duration_ms, cols, rows, event_count, summary, auto_recorded,
                        started_at, ended_at, created_at, parent_id, is_encrypted)
                     VALUES (?1, ?2, '', ?3, ?4, 0, 0, 80, 24, 0, NULL, 0, ?5, NULL, ?5, NULL, 0)",
                    rusqlite::params![
                        id, session_id, title.clone().unwrap_or_default(), file_path, now,
                    ],
                )?;
                Ok(())
            })
            .map_err(|e| e.to_string())
        })?;
    } else {
        let entry = RecordingEntry {
            id: id.clone(),
            session_id,
            title,
            file_path,
            duration_seconds: 0,
            size_bytes: 0,
            created_at: chrono::Utc::now().to_rfc3339(),
        };
        RECORDING_REGISTRY.lock().unwrap().insert(id.clone(), entry);
    }

    Ok(id)
}

/// Stops an active recording and returns its metadata.
pub fn recording_stop(recording_id: String) -> Result<RecordingEntry, String> {
    if db_state::is_unlocked() {
        // Fill in ended_at + return DTO.
        let entry = db_state::with_db(|db| {
            db.with_conn(|conn| {
                let now = chrono::Utc::now().to_rfc3339();
                conn.execute(
                    "UPDATE recordings SET ended_at = ?1 WHERE id = ?2",
                    rusqlite::params![now, recording_id],
                )?;
                let row: Option<(String, String, String, u64, u64, String)> = conn
                    .query_row(
                        "SELECT id, session_id, COALESCE(server_name, ''), duration_ms, file_size, created_at
                         FROM recordings WHERE id = ?1",
                        rusqlite::params![recording_id],
                        |r| {
                            Ok((
                                r.get::<_, String>(0)?,
                                r.get::<_, String>(1)?,
                                r.get::<_, String>(2)?,
                                r.get::<_, u64>(3)?,
                                r.get::<_, u64>(4)?,
                                r.get::<_, String>(5)?,
                            ))
                        },
                    )
                    .ok();
                Ok(row.map(|(id, sid, title, dur_ms, size, created)| RecordingEntry {
                    id,
                    session_id: sid,
                    title: Some(title),
                    file_path: String::new(),
                    duration_seconds: dur_ms / 1000,
                    size_bytes: size,
                    created_at: created,
                }))
            })
            .map_err(|e| e.to_string())
        })?;
        if let Some(e) = entry {
            return Ok(e);
        }
    }

    // Fallback: in-memory.
    let reg = RECORDING_REGISTRY.lock().unwrap();
    if let Some(entry) = reg.get(&recording_id) {
        Ok(entry.clone())
    } else {
        Ok(RecordingEntry {
            id: recording_id.clone(),
            session_id: String::new(),
            title: None,
            file_path: format!("/tmp/{recording_id}.cast"),
            duration_seconds: 0,
            size_bytes: 0,
            created_at: chrono::Utc::now().to_rfc3339(),
        })
    }
}

/// Lists all known recordings (legacy DTO).
pub fn recording_list() -> Result<Vec<RecordingEntry>, String> {
    if !db_state::is_unlocked() {
        return Ok(vec![]);
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, session_id, COALESCE(server_name, ''), file_path,
                        duration_ms, file_size, created_at
                 FROM recordings ORDER BY created_at DESC",
            )?;
            let iter = stmt.query_map([], |r| {
                Ok(RecordingEntry {
                    id: r.get::<_, String>(0)?,
                    session_id: r.get::<_, String>(1)?,
                    title: {
                        let s: String = r.get(2)?;
                        if s.is_empty() { None } else { Some(s) }
                    },
                    file_path: r.get(3)?,
                    duration_seconds: r.get::<_, u64>(4)? / 1000,
                    size_bytes: r.get(5)?,
                    created_at: r.get(6)?,
                })
            })?;
            let mut out = Vec::new();
            for row in iter {
                if let Ok(e) = row {
                    out.push(e);
                }
            }
            Ok(out)
        })
        .map_err(|e| e.to_string())
    })
}

/// Lists recordings with the full v0.47 DTO shape.
pub fn recording_list_full() -> Result<Vec<RecordingDto>, String> {
    if !db_state::is_unlocked() {
        return Ok(vec![]);
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, session_id, COALESCE(server_id, ''), COALESCE(server_name, ''),
                        file_path, file_size, duration_ms, cols, rows, event_count, summary,
                        auto_recorded, started_at, ended_at,
                        parent_id, COALESCE(is_encrypted, 0)
                 FROM recordings ORDER BY started_at DESC",
            )?;
            let iter = stmt.query_map([], |r| {
                Ok(RecordingDto {
                    id: r.get(0)?,
                    session_id: r.get(1)?,
                    server_id: r.get(2)?,
                    server_name: r.get(3)?,
                    file_path: r.get(4)?,
                    file_size: r.get(5)?,
                    duration_ms: r.get(6)?,
                    cols: r.get(7)?,
                    rows: r.get(8)?,
                    event_count: r.get(9)?,
                    summary: r.get(10)?,
                    auto_recorded: r.get::<_, i32>(11)? != 0,
                    started_at: r.get(12)?,
                    ended_at: r.get(13)?,
                    parent_id: r.get(14)?,
                    is_encrypted: r.get::<_, i32>(15)? != 0,
                })
            })?;
            let mut out = Vec::new();
            for row in iter {
                if let Ok(e) = row {
                    out.push(e);
                }
            }
            Ok(out)
        })
        .map_err(|e| e.to_string())
    })
}

/// Registers a follow-up part (part2+) linked to `parent_id`.
pub fn recording_register_part(
    parent_id: String,
    session_id: String,
    file_path: String,
) -> Result<String, String> {
    if !db_state::is_unlocked() {
        return Ok(uuid::Uuid::new_v4().to_string());
    }
    let id = uuid::Uuid::new_v4().to_string();
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let now = chrono::Utc::now().to_rfc3339();
            conn.execute(
                "INSERT INTO recordings
                   (id, session_id, server_id, server_name, file_path, file_size,
                    duration_ms, cols, rows, event_count, summary, auto_recorded,
                    started_at, ended_at, created_at, parent_id, is_encrypted)
                 VALUES (?1, ?2, '', '', ?3, 0, 0, 80, 24, 0, NULL, 0, ?4, NULL, ?4, ?5, 0)",
                rusqlite::params![id, session_id, file_path, now, parent_id],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })?;
    Ok(id)
}

/// Deletes a recording by `id` (cascade to parts is NOT applied — call the
/// helper below to delete a full group).
pub fn recording_delete(id: String) -> Result<(), String> {
    if db_state::is_unlocked() {
        db_state::with_db(|db| {
            db.with_conn(|conn| {
                conn.execute("DELETE FROM recordings WHERE id = ?1", rusqlite::params![id])?;
                Ok(())
            })
            .map_err(|e| e.to_string())
        })?;
    } else {
        RECORDING_REGISTRY.lock().unwrap().remove(&id);
    }
    Ok(())
}

/// Deletes a recording and every follow-up part linked to it.
pub fn recording_delete_group(parent_id: String) -> Result<u32, String> {
    if !db_state::is_unlocked() {
        return Ok(0);
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let parts: u32 = conn.execute(
                "DELETE FROM recordings WHERE id = ?1 OR parent_id = ?1",
                rusqlite::params![parent_id],
            )? as u32;
            Ok(parts)
        })
        .map_err(|e| e.to_string())
    })
}

/// Returns the filesystem path for a recording's `.cast` file.
pub fn recording_get_path(id: String) -> Result<String, String> {
    if !db_state::is_unlocked() {
        return Ok(format!("/tmp/{id}.cast"));
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let row: Option<String> = conn
                .query_row(
                    "SELECT file_path FROM recordings WHERE id = ?1",
                    rusqlite::params![id],
                    |r| r.get(0),
                )
                .ok();
            Ok(row.unwrap_or_else(|| format!("/tmp/{id}.cast")))
        })
        .map_err(|e| e.to_string())
    })
}

/// Exports a recording to `dest_path`.  Copies the underlying `.cast` file.
pub fn recording_export(id: String, dest_path: String) -> Result<(), String> {
    let source = recording_get_path(id.clone())?;
    if std::path::Path::new(&source).exists() {
        std::fs::copy(&source, &dest_path)
            .map_err(|e| format!("copy recording: {e}"))?;
    }
    // Audit.
    let _ = crate::api::settings::audit_append(
        "recording.export",
        &format!("id={id} dest={dest_path}"),
    );
    Ok(())
}

/// Marks `id` as encrypted (after caller has re-encrypted the underlying file).
pub fn recording_mark_encrypted(id: String) -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "UPDATE recordings SET is_encrypted = 1 WHERE id = ?1",
                rusqlite::params![id],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Deletes recordings older than `days` days.  Returns count deleted.
pub fn recording_cleanup_expired(days: u32) -> Result<u32, String> {
    if !db_state::is_unlocked() || days == 0 {
        return Ok(0);
    }
    let cutoff =
        (chrono::Utc::now() - chrono::Duration::days(days as i64)).to_rfc3339();
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let n = conn.execute(
                "DELETE FROM recordings WHERE created_at < ?1",
                rusqlite::params![cutoff],
            )?;
            Ok(n as u32)
        })
        .map_err(|e| e.to_string())
    })
}

/// For tests: clears the in-memory recording registry.
pub fn _test_clear_registry() {
    RECORDING_REGISTRY.lock().unwrap().clear();
}
