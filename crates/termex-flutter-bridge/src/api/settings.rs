/// Settings and privacy APIs exposed to Flutter via FRB.
///
/// Covers app appearance, terminal behaviour, AI preferences, backup/audit
/// configuration, and GDPR-mandated data-erasure functions.
///
/// Settings persist to the `settings` KV table (created in V1). When the
/// database is not yet unlocked (e.g. during integration tests without
/// `db_state::init_for_test`), all functions fall back to in-memory defaults.
use flutter_rust_bridge::frb;
use std::collections::HashMap;

use crate::db_state;

// ─── DTOs ────────────────────────────────────────────────────────────────────

/// Snapshot of every user-configurable setting.
#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AppSettings {
    /// Theme mode: `"dark"` | `"light"` | `"system"`.
    pub theme_mode: String,
    /// Terminal colour-scheme name (e.g. `"One Dark"`).
    pub color_scheme: String,
    /// Terminal font family.
    pub font_family: String,
    /// Terminal font size in points.
    pub font_size: f32,
    /// Cursor shape: `"block"` | `"underline"` | `"bar"`.
    pub cursor_shape: String,
    /// Whether the cursor blinks.
    pub cursor_blink: bool,
    /// Number of lines to keep in the scrollback buffer.
    pub scrollback_lines: i32,
    /// Tab-stop width: `2` | `4` | `8`.
    pub tab_width: i32,
    /// UI language: `"zh-CN"` | `"en-US"`.
    pub language: String,
    /// Automatically run AI diagnostics on command failure.
    pub ai_auto_diagnose: bool,
    /// Number of terminal lines to include in AI context.
    pub ai_context_lines: i32,
    /// Automated backup frequency: `"off"` | `"daily"` | `"weekly"`.
    pub backup_frequency: String,
    /// Audit-log retention: `30` | `90` | `365` | `-1` (永久 / forever).
    pub audit_retention_days: i32,
    /// TCP port for the local AI model server.
    pub local_ai_port: i32,
    /// CPU-thread count for local AI inference.
    pub local_ai_threads: i32,
    /// Context-window size (tokens) for local AI.
    pub local_ai_context_size: i32,
    /// Path to kubeconfig file used by cloud K8s integration (§13.5 of v0.46 spec).
    pub k8s_kubeconfig_path: String,

    // ── Local AI ────────────────────────────────────────────────────────────
    /// Auto-start the local llama.cpp server on app launch.
    pub local_ai_auto_start: bool,

    // ── Keyword highlight rules ─────────────────────────────────────────────
    /// JSON array of keyword highlight rules (HighlightsTab).
    /// Schema: `[{"pattern":"foo","color":"#ff0000","caseSensitive":false}]`.
    pub keyword_rules_json: String,

    // ── Monitor panel ───────────────────────────────────────────────────────
    /// Polling interval (milliseconds) for monitor metrics collector.
    pub monitor_interval_ms: i32,
    /// Auto-start monitor collector when an SSH session opens.
    pub monitor_auto_start: bool,
    /// Render CPU panel in monitor view.
    pub monitor_show_cpu: bool,
    /// Render memory panel in monitor view.
    pub monitor_show_memory: bool,
    /// Render disk panel in monitor view.
    pub monitor_show_disk: bool,
    /// Render network panel in monitor view.
    pub monitor_show_network: bool,
    /// Render process list in monitor view.
    pub monitor_show_processes: bool,

    // ── Recording ───────────────────────────────────────────────────────────
    /// Recording retention in days (-1 = keep forever).
    pub recording_retention_days: i32,
    /// Recording file format: `"asciicast"` | `"json"` | `"text"`.
    pub recording_format: String,
}

impl Default for AppSettings {
    fn default() -> Self {
        AppSettings {
            theme_mode: "system".into(),
            color_scheme: "One Dark".into(),
            font_family: "JetBrains Mono".into(),
            font_size: 14.0,
            cursor_shape: "block".into(),
            cursor_blink: true,
            scrollback_lines: 5000,
            tab_width: 4,
            language: "en-US".into(),
            ai_auto_diagnose: true,
            ai_context_lines: 50,
            backup_frequency: "weekly".into(),
            audit_retention_days: 90,
            local_ai_port: 11434,
            local_ai_threads: 4,
            local_ai_context_size: 4096,
            k8s_kubeconfig_path: "~/.kube/config".into(),
            local_ai_auto_start: true,
            keyword_rules_json: "[]".into(),
            monitor_interval_ms: 2000,
            monitor_auto_start: false,
            monitor_show_cpu: true,
            monitor_show_memory: true,
            monitor_show_disk: true,
            monitor_show_network: true,
            monitor_show_processes: true,
            recording_retention_days: 30,
            recording_format: "asciicast".into(),
        }
    }
}

/// A single entry in the audit log.
#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AuditLogEntry {
    pub id: String,
    pub event_type: String,
    pub detail: String,
    pub created_at: String,
}

// ─── Key constants for the settings KV table ─────────────────────────────────

const K_THEME_MODE: &str = "theme_mode";
const K_COLOR_SCHEME: &str = "color_scheme";
const K_FONT_FAMILY: &str = "font_family";
const K_FONT_SIZE: &str = "font_size";
const K_CURSOR_SHAPE: &str = "cursor_shape";
const K_CURSOR_BLINK: &str = "cursor_blink";
const K_SCROLLBACK_LINES: &str = "scrollback_lines";
const K_TAB_WIDTH: &str = "tab_width";
const K_LANGUAGE: &str = "ui_language";
const K_AI_AUTO_DIAGNOSE: &str = "ai_auto_diagnose";
const K_AI_CONTEXT_LINES: &str = "ai_context_lines";
const K_BACKUP_FREQUENCY: &str = "auto_backup_frequency";
const K_AUDIT_RETENTION: &str = "audit_retention_days";
const K_LOCAL_AI_PORT: &str = "local_ai_port";
const K_LOCAL_AI_THREADS: &str = "local_ai_threads";
const K_LOCAL_AI_CONTEXT_SIZE: &str = "local_ai_context_size";
const K_K8S_KUBECONFIG_PATH: &str = "k8s_kubeconfig_path";
const K_LOCAL_AI_AUTO_START: &str = "local_ai_auto_start";
const K_KEYWORD_RULES_JSON: &str = "keyword_rules_json";
const K_MONITOR_INTERVAL_MS: &str = "monitor_interval_ms";
const K_MONITOR_AUTO_START: &str = "monitor_auto_start";
const K_MONITOR_SHOW_CPU: &str = "monitor_show_cpu";
const K_MONITOR_SHOW_MEMORY: &str = "monitor_show_memory";
const K_MONITOR_SHOW_DISK: &str = "monitor_show_disk";
const K_MONITOR_SHOW_NETWORK: &str = "monitor_show_network";
const K_MONITOR_SHOW_PROCESSES: &str = "monitor_show_processes";
const K_RECORDING_RETENTION_DAYS: &str = "recording_retention_days";
const K_RECORDING_FORMAT: &str = "recording_format";

const ALL_KEYS: &[&str] = &[
    K_THEME_MODE,
    K_COLOR_SCHEME,
    K_FONT_FAMILY,
    K_FONT_SIZE,
    K_CURSOR_SHAPE,
    K_CURSOR_BLINK,
    K_SCROLLBACK_LINES,
    K_TAB_WIDTH,
    K_LANGUAGE,
    K_AI_AUTO_DIAGNOSE,
    K_AI_CONTEXT_LINES,
    K_BACKUP_FREQUENCY,
    K_AUDIT_RETENTION,
    K_LOCAL_AI_PORT,
    K_LOCAL_AI_THREADS,
    K_LOCAL_AI_CONTEXT_SIZE,
    K_K8S_KUBECONFIG_PATH,
    K_LOCAL_AI_AUTO_START,
    K_KEYWORD_RULES_JSON,
    K_MONITOR_INTERVAL_MS,
    K_MONITOR_AUTO_START,
    K_MONITOR_SHOW_CPU,
    K_MONITOR_SHOW_MEMORY,
    K_MONITOR_SHOW_DISK,
    K_MONITOR_SHOW_NETWORK,
    K_MONITOR_SHOW_PROCESSES,
    K_RECORDING_RETENTION_DAYS,
    K_RECORDING_FORMAT,
];

// ─── Settings CRUD ───────────────────────────────────────────────────────────

/// Loads settings from the database.  Any key missing from the table falls
/// back to its built-in default.  When the database is not unlocked the
/// built-in defaults are returned.
#[frb]
pub fn settings_load() -> Result<AppSettings, String> {
    if !db_state::is_unlocked() {
        return Ok(AppSettings::default());
    }

    db_state::with_db(|db| {
        let rows = db
            .with_conn(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT key, value FROM settings WHERE key IN
                    ('theme_mode','color_scheme','font_family','font_size','cursor_shape',
                     'cursor_blink','scrollback_lines','tab_width','ui_language',
                     'ai_auto_diagnose','ai_context_lines','auto_backup_frequency',
                     'audit_retention_days','local_ai_port','local_ai_threads',
                     'local_ai_context_size','k8s_kubeconfig_path',
                     'local_ai_auto_start','keyword_rules_json',
                     'monitor_interval_ms','monitor_auto_start',
                     'monitor_show_cpu','monitor_show_memory','monitor_show_disk',
                     'monitor_show_network','monitor_show_processes',
                     'recording_retention_days','recording_format')",
                )?;
                let mut map = HashMap::new();
                let iter = stmt.query_map([], |r| {
                    Ok((r.get::<_, String>(0)?, r.get::<_, String>(1)?))
                })?;
                for row in iter {
                    let (k, v) = row?;
                    map.insert(k, v);
                }
                Ok(map)
            })
            .map_err(|e| e.to_string())?;

        Ok(map_to_settings(&rows))
    })
}

fn map_to_settings(m: &HashMap<String, String>) -> AppSettings {
    let d = AppSettings::default();
    AppSettings {
        theme_mode: m.get(K_THEME_MODE).cloned().unwrap_or(d.theme_mode),
        color_scheme: m.get(K_COLOR_SCHEME).cloned().unwrap_or(d.color_scheme),
        font_family: m.get(K_FONT_FAMILY).cloned().unwrap_or(d.font_family),
        font_size: m.get(K_FONT_SIZE).and_then(|v| v.parse().ok()).unwrap_or(d.font_size),
        cursor_shape: m.get(K_CURSOR_SHAPE).cloned().unwrap_or(d.cursor_shape),
        cursor_blink: m
            .get(K_CURSOR_BLINK)
            .map(|v| v == "true" || v == "1")
            .unwrap_or(d.cursor_blink),
        scrollback_lines: m
            .get(K_SCROLLBACK_LINES)
            .and_then(|v| v.parse().ok())
            .unwrap_or(d.scrollback_lines),
        tab_width: m.get(K_TAB_WIDTH).and_then(|v| v.parse().ok()).unwrap_or(d.tab_width),
        language: m.get(K_LANGUAGE).cloned().unwrap_or(d.language),
        ai_auto_diagnose: m
            .get(K_AI_AUTO_DIAGNOSE)
            .map(|v| v == "true" || v == "1")
            .unwrap_or(d.ai_auto_diagnose),
        ai_context_lines: m
            .get(K_AI_CONTEXT_LINES)
            .and_then(|v| v.parse().ok())
            .unwrap_or(d.ai_context_lines),
        backup_frequency: m.get(K_BACKUP_FREQUENCY).cloned().unwrap_or(d.backup_frequency),
        audit_retention_days: m
            .get(K_AUDIT_RETENTION)
            .and_then(|v| v.parse().ok())
            .unwrap_or(d.audit_retention_days),
        local_ai_port: m
            .get(K_LOCAL_AI_PORT)
            .and_then(|v| v.parse().ok())
            .unwrap_or(d.local_ai_port),
        local_ai_threads: m
            .get(K_LOCAL_AI_THREADS)
            .and_then(|v| v.parse().ok())
            .unwrap_or(d.local_ai_threads),
        local_ai_context_size: m
            .get(K_LOCAL_AI_CONTEXT_SIZE)
            .and_then(|v| v.parse().ok())
            .unwrap_or(d.local_ai_context_size),
        k8s_kubeconfig_path: m
            .get(K_K8S_KUBECONFIG_PATH)
            .cloned()
            .unwrap_or(d.k8s_kubeconfig_path),
        local_ai_auto_start: m
            .get(K_LOCAL_AI_AUTO_START)
            .map(|v| v == "true" || v == "1")
            .unwrap_or(d.local_ai_auto_start),
        keyword_rules_json: m
            .get(K_KEYWORD_RULES_JSON)
            .cloned()
            .unwrap_or(d.keyword_rules_json),
        monitor_interval_ms: m
            .get(K_MONITOR_INTERVAL_MS)
            .and_then(|v| v.parse().ok())
            .unwrap_or(d.monitor_interval_ms),
        monitor_auto_start: m
            .get(K_MONITOR_AUTO_START)
            .map(|v| v == "true" || v == "1")
            .unwrap_or(d.monitor_auto_start),
        monitor_show_cpu: m
            .get(K_MONITOR_SHOW_CPU)
            .map(|v| v == "true" || v == "1")
            .unwrap_or(d.monitor_show_cpu),
        monitor_show_memory: m
            .get(K_MONITOR_SHOW_MEMORY)
            .map(|v| v == "true" || v == "1")
            .unwrap_or(d.monitor_show_memory),
        monitor_show_disk: m
            .get(K_MONITOR_SHOW_DISK)
            .map(|v| v == "true" || v == "1")
            .unwrap_or(d.monitor_show_disk),
        monitor_show_network: m
            .get(K_MONITOR_SHOW_NETWORK)
            .map(|v| v == "true" || v == "1")
            .unwrap_or(d.monitor_show_network),
        monitor_show_processes: m
            .get(K_MONITOR_SHOW_PROCESSES)
            .map(|v| v == "true" || v == "1")
            .unwrap_or(d.monitor_show_processes),
        recording_retention_days: m
            .get(K_RECORDING_RETENTION_DAYS)
            .and_then(|v| v.parse().ok())
            .unwrap_or(d.recording_retention_days),
        recording_format: m
            .get(K_RECORDING_FORMAT)
            .cloned()
            .unwrap_or(d.recording_format),
    }
}

fn settings_to_pairs(s: &AppSettings) -> Vec<(&'static str, String)> {
    vec![
        (K_THEME_MODE, s.theme_mode.clone()),
        (K_COLOR_SCHEME, s.color_scheme.clone()),
        (K_FONT_FAMILY, s.font_family.clone()),
        (K_FONT_SIZE, s.font_size.to_string()),
        (K_CURSOR_SHAPE, s.cursor_shape.clone()),
        (K_CURSOR_BLINK, s.cursor_blink.to_string()),
        (K_SCROLLBACK_LINES, s.scrollback_lines.to_string()),
        (K_TAB_WIDTH, s.tab_width.to_string()),
        (K_LANGUAGE, s.language.clone()),
        (K_AI_AUTO_DIAGNOSE, s.ai_auto_diagnose.to_string()),
        (K_AI_CONTEXT_LINES, s.ai_context_lines.to_string()),
        (K_BACKUP_FREQUENCY, s.backup_frequency.clone()),
        (K_AUDIT_RETENTION, s.audit_retention_days.to_string()),
        (K_LOCAL_AI_PORT, s.local_ai_port.to_string()),
        (K_LOCAL_AI_THREADS, s.local_ai_threads.to_string()),
        (K_LOCAL_AI_CONTEXT_SIZE, s.local_ai_context_size.to_string()),
        (K_K8S_KUBECONFIG_PATH, s.k8s_kubeconfig_path.clone()),
        (K_LOCAL_AI_AUTO_START, s.local_ai_auto_start.to_string()),
        (K_KEYWORD_RULES_JSON, s.keyword_rules_json.clone()),
        (K_MONITOR_INTERVAL_MS, s.monitor_interval_ms.to_string()),
        (K_MONITOR_AUTO_START, s.monitor_auto_start.to_string()),
        (K_MONITOR_SHOW_CPU, s.monitor_show_cpu.to_string()),
        (K_MONITOR_SHOW_MEMORY, s.monitor_show_memory.to_string()),
        (K_MONITOR_SHOW_DISK, s.monitor_show_disk.to_string()),
        (K_MONITOR_SHOW_NETWORK, s.monitor_show_network.to_string()),
        (K_MONITOR_SHOW_PROCESSES, s.monitor_show_processes.to_string()),
        (K_RECORDING_RETENTION_DAYS, s.recording_retention_days.to_string()),
        (K_RECORDING_FORMAT, s.recording_format.clone()),
    ]
}

/// Persists `settings` to the `settings` KV table.  No-op when the database
/// is not unlocked.
#[frb]
pub fn settings_save(settings: AppSettings) -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }

    let pairs = settings_to_pairs(&settings);
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let now = chrono::Utc::now().to_rfc3339();
            for (k, v) in &pairs {
                conn.execute(
                    "INSERT INTO settings (key, value, updated_at) VALUES (?1, ?2, ?3)
                     ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at",
                    rusqlite::params![k, v, now],
                )?;
            }
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Exports the full settings bundle to a password-protected `.termex` file.
///
/// When `password` is empty the payload is written as plain JSON with
/// `schema_version: 2`; otherwise it is wrapped in the AES-256-GCM +
/// Argon2id binary container described in §4.8.5 of the v0.46 spec.
#[frb]
pub fn settings_export(path: String, password: String) -> Result<(), String> {
    let json = settings_export_to_json()?;

    if password.is_empty() {
        std::fs::write(&path, json).map_err(|e| format!("write export file: {e}"))?;
    } else {
        crate::api::backup::backup_encrypt_to_file(path, password, json)?;
    }
    Ok(())
}

/// Builds the JSON payload used by the export / backup-scheduler paths.
/// Exposed at module scope so non-FRB code in the bridge crate (e.g. the
/// G1 BackupScheduler runner) can reuse the exact same envelope shape.
#[frb(ignore)]
pub fn settings_export_to_json() -> Result<String, String> {
    let current = settings_load()?;
    let payload = serde_json::json!({
        "schema_version": 2,
        "exported_at": chrono::Utc::now().to_rfc3339(),
        "settings": current,
    });
    serde_json::to_string_pretty(&payload).map_err(|e| e.to_string())
}

/// Imports settings from an export file.  Handles both plain-JSON and
/// encrypted `.termex` files (magic-number sniffing).
#[frb]
pub fn settings_import(path: String, password: String) -> Result<AppSettings, String> {
    let bytes = match std::fs::read(&path) {
        Ok(b) => b,
        Err(_) => return Ok(AppSettings::default()),
    };

    let raw = if bytes.len() >= 4 && &bytes[0..4] == b"TRMX" {
        crate::api::backup::backup_decrypt_from_file(path, password)?
    } else {
        String::from_utf8(bytes).map_err(|_| "Export file is not valid UTF-8".to_string())?
    };

    let value: serde_json::Value = serde_json::from_str(&raw).map_err(|e| e.to_string())?;
    let settings: AppSettings = match value.get("settings") {
        Some(inner) => serde_json::from_value(inner.clone()).unwrap_or_default(),
        None => AppSettings::default(),
    };
    settings_save(settings.clone())?;
    Ok(settings)
}

/// Resets every setting to its built-in default value by clearing overrides
/// from the `settings` KV table.
#[frb]
pub fn settings_reset_to_defaults() -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }

    db_state::with_db(|db| {
        db.with_conn(|conn| {
            for k in ALL_KEYS {
                conn.execute("DELETE FROM settings WHERE key = ?1", rusqlite::params![k])?;
            }
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

// ─── Privacy ─────────────────────────────────────────────────────────────────

/// Deletes all rows from the `quick_connect_history` table.
#[frb]
pub fn privacy_clear_connection_history() -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute("DELETE FROM quick_connect_history", [])?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Deletes all AI conversation records (cascades to `ai_messages`).
#[frb]
pub fn privacy_clear_ai_conversations() -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute("DELETE FROM ai_messages", [])?;
            conn.execute("DELETE FROM ai_conversations", [])?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Resets snippet usage statistics (use counts and last-used timestamps).
#[frb]
pub fn privacy_clear_snippet_stats() -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "UPDATE snippets SET usage_count = 0, last_used_at = NULL",
                [],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Permanently erases **all** user data after verifying the confirmation
/// string matches `"DELETE ALL"`.  `master_password` is accepted but not yet
/// verified (master-password store lives in the keychain module which is
/// desktop-only).
///
/// Returns `Err("Confirmation text mismatch")` if the confirmation is wrong.
#[frb]
pub fn privacy_gdpr_erase_all(
    master_password: String,
    confirmation: String,
) -> Result<(), String> {
    if confirmation != "DELETE ALL" {
        return Err("Confirmation text mismatch".into());
    }
    let _ = master_password;
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            // Business data — keep meta tables (_migrations) intact.
            let tables = [
                "ai_messages",
                "ai_conversations",
                "quick_connect_history",
                "command_history",
                "audit_log",
                "recordings",
                "snippets",
                "snippet_folders",
                "connection_chain",
                "port_forwards",
                "servers",
                "groups",
                "proxies",
                "ssh_keys",
                "ai_providers",
                "cloud_favorites",
                "cloud_profiles",
                "known_hosts",
                "keybindings",
                "team_pending_conflicts",
                "settings",
            ];
            for t in &tables {
                let _ = conn.execute(&format!("DELETE FROM {t}"), []);
            }
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

// ─── Audit log ───────────────────────────────────────────────────────────────

/// Returns up to `limit` audit-log entries, optionally filtered by
/// `event_type`.  Results are ordered newest-first.
#[frb]
pub fn audit_list(
    limit: i32,
    event_type: Option<String>,
) -> Result<Vec<AuditLogEntry>, String> {
    if !db_state::is_unlocked() {
        return Ok(vec![]);
    }

    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let limit = limit.max(1);
            let mut rows: Vec<AuditLogEntry> = Vec::new();
            match &event_type {
                Some(t) => {
                    let mut stmt = conn.prepare(
                        "SELECT id, event_type, COALESCE(detail, ''), timestamp
                         FROM audit_log WHERE event_type = ?1
                         ORDER BY id DESC LIMIT ?2",
                    )?;
                    let iter = stmt.query_map(rusqlite::params![t, limit], |r| {
                        Ok(AuditLogEntry {
                            id: r.get::<_, i64>(0)?.to_string(),
                            event_type: r.get(1)?,
                            detail: r.get(2)?,
                            created_at: r.get(3)?,
                        })
                    })?;
                    for row in iter {
                        if let Ok(e) = row {
                            rows.push(e);
                        }
                    }
                }
                None => {
                    let mut stmt = conn.prepare(
                        "SELECT id, event_type, COALESCE(detail, ''), timestamp
                         FROM audit_log ORDER BY id DESC LIMIT ?1",
                    )?;
                    let iter = stmt.query_map(rusqlite::params![limit], |r| {
                        Ok(AuditLogEntry {
                            id: r.get::<_, i64>(0)?.to_string(),
                            event_type: r.get(1)?,
                            detail: r.get(2)?,
                            created_at: r.get(3)?,
                        })
                    })?;
                    for row in iter {
                        if let Ok(e) = row {
                            rows.push(e);
                        }
                    }
                }
            }
            Ok(rows)
        })
        .map_err(|e| e.to_string())
    })
}

/// Appends one audit log entry.  Detail is stored verbatim — callers are
/// responsible for redaction before invoking this function (§12.8 of spec).
pub fn audit_append(event_type: &str, detail: &str) -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let now = chrono::Utc::now().to_rfc3339();
            conn.execute(
                "INSERT INTO audit_log (timestamp, event_type, detail) VALUES (?1, ?2, ?3)",
                rusqlite::params![now, event_type, detail],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Exports audit-log entries from the last `days` days (or all if `None`) to a
/// CSV file at `path`.  Format: UTF-8 with BOM, headers
/// `timestamp,event_type,detail`.  Empty database writes only the header row.
#[frb]
pub fn audit_export_csv(path: String, days: Option<i32>) -> Result<(), String> {
    let mut content = String::from("\u{FEFF}timestamp,event_type,detail\n");

    if db_state::is_unlocked() {
        db_state::with_db(|db| {
            db.with_conn(|conn| {
                let since = days.map(|d| {
                    (chrono::Utc::now() - chrono::Duration::days(d as i64)).to_rfc3339()
                });
                let mut rows: Vec<(String, String, String)> = Vec::new();
                match &since {
                    Some(ts) => {
                        let mut stmt = conn.prepare(
                            "SELECT timestamp, event_type, COALESCE(detail, '')
                             FROM audit_log WHERE timestamp >= ?1 ORDER BY id ASC",
                        )?;
                        let iter = stmt.query_map(rusqlite::params![ts], |r| {
                            Ok((
                                r.get::<_, String>(0)?,
                                r.get::<_, String>(1)?,
                                r.get::<_, String>(2)?,
                            ))
                        })?;
                        for row in iter {
                            if let Ok(t) = row {
                                rows.push(t);
                            }
                        }
                    }
                    None => {
                        let mut stmt = conn.prepare(
                            "SELECT timestamp, event_type, COALESCE(detail, '')
                             FROM audit_log ORDER BY id ASC",
                        )?;
                        let iter = stmt.query_map([], |r| {
                            Ok((
                                r.get::<_, String>(0)?,
                                r.get::<_, String>(1)?,
                                r.get::<_, String>(2)?,
                            ))
                        })?;
                        for row in iter {
                            if let Ok(t) = row {
                                rows.push(t);
                            }
                        }
                    }
                }
                for (ts, et, d) in rows {
                    content.push_str(&format!("{},{},{}\n", csv_escape(&ts), csv_escape(&et), csv_escape(&d)));
                }
                Ok(())
            })
            .map_err(|e| e.to_string())
        })?;
    }

    std::fs::write(&path, content).map_err(|e| format!("write CSV: {e}"))?;
    Ok(())
}

fn csv_escape(s: &str) -> String {
    if s.contains(',') || s.contains('"') || s.contains('\n') {
        let escaped = s.replace('"', "\"\"");
        format!("\"{escaped}\"")
    } else {
        s.to_string()
    }
}
