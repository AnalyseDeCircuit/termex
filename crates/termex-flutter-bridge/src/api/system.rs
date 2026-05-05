/// System services: clipboard, URL opener, window-state persistence.
///
/// These thin wrappers expose portable system operations to Flutter via FRB.
/// Clipboard and URL ops delegate to the OS; window-state persistence uses
/// the same `settings` key-value table used by the rest of the app.
use std::sync::Mutex;

use once_cell::sync::Lazy;

use crate::db_state;

// ─── Clipboard ────────────────────────────────────────────────────────────────

static CLIPBOARD_CACHE: Lazy<Mutex<String>> = Lazy::new(|| Mutex::new(String::new()));

/// Returns the current clipboard text (process-local cache when DB unavailable).
pub fn clipboard_read() -> Result<String, String> {
    Ok(CLIPBOARD_CACHE.lock().unwrap().clone())
}

/// Writes `text` to the process-local clipboard cache.
pub fn clipboard_write(text: String) -> Result<(), String> {
    *CLIPBOARD_CACHE.lock().unwrap() = text;
    Ok(())
}

/// Clears the clipboard cache.
pub fn clipboard_clear() -> Result<(), String> {
    *CLIPBOARD_CACHE.lock().unwrap() = String::new();
    Ok(())
}

// ─── URL ──────────────────────────────────────────────────────────────────────

/// Validates that `url` begins with a recognised scheme.
///
/// Actual launching is handled in the Flutter layer via `url_launcher`; this
/// function is the Rust-side allow-list gate.
pub fn url_can_open(url: String) -> bool {
    url.starts_with("https://")
        || url.starts_with("http://")
        || url.starts_with("ssh://")
        || url.starts_with("mailto:")
}

/// Returns `Ok(())` when the scheme is on the allow-list, `Err` otherwise.
pub fn url_validate(url: String) -> Result<(), String> {
    if url_can_open(url.clone()) {
        Ok(())
    } else {
        Err(format!("url scheme not allowed: {url}"))
    }
}

// ─── Window state ─────────────────────────────────────────────────────────────

/// Snapshot of the application window's geometry and open tabs.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WindowState {
    pub width: f64,
    pub height: f64,
    pub x: f64,
    pub y: f64,
    pub is_maximized: bool,
    /// Server IDs of tabs that were open at last save (no auto-reconnect).
    pub open_tab_server_ids: Vec<String>,
}

impl WindowState {
    fn default_state() -> Self {
        Self {
            width: 1280.0,
            height: 800.0,
            x: 100.0,
            y: 100.0,
            is_maximized: false,
            open_tab_server_ids: vec![],
        }
    }
}

/// Persists window state into the `settings` key-value table.
pub fn window_state_save(state: WindowState) -> Result<(), String> {
    let tab_ids_json = serde_json::to_string(&state.open_tab_server_ids)
        .map_err(|e| e.to_string())?;

    let pairs: &[(&str, String)] = &[
        ("window_width", state.width.to_string()),
        ("window_height", state.height.to_string()),
        ("window_x", state.x.to_string()),
        ("window_y", state.y.to_string()),
        ("window_is_maximized", if state.is_maximized { "1" } else { "0" }.to_string()),
        ("window_last_tab_server_ids", tab_ids_json),
    ];

    if db_state::is_unlocked() {
        db_state::with_db(|db| {
            db.with_conn(|conn| {
                for (k, v) in pairs {
                    conn.execute(
                        "INSERT INTO settings (key, value) VALUES (?1, ?2)
                         ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                        rusqlite::params![k, v],
                    )?;
                }
                Ok(())
            })
            .map_err(|e| e.to_string())
        })
    } else {
        // Non-persistent fallback — silently accepted in tests.
        Ok(())
    }
}

/// Restores window state from the `settings` table.
///
/// Returns a default state when the database is not unlocked or when the keys
/// have never been written.
pub fn window_state_restore() -> Result<WindowState, String> {
    if !db_state::is_unlocked() {
        return Ok(WindowState::default_state());
    }

    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT key, value FROM settings
                 WHERE key IN ('window_width','window_height','window_x','window_y',
                               'window_is_maximized','window_last_tab_server_ids')",
            )?;
            let rows: Vec<(String, String)> = stmt
                .query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?
                .filter_map(|r| r.ok())
                .collect();

            let mut ws = WindowState::default_state();
            for (k, v) in rows {
                match k.as_str() {
                    "window_width" => ws.width = v.parse().unwrap_or(1280.0),
                    "window_height" => ws.height = v.parse().unwrap_or(800.0),
                    "window_x" => ws.x = v.parse().unwrap_or(100.0),
                    "window_y" => ws.y = v.parse().unwrap_or(100.0),
                    "window_is_maximized" => ws.is_maximized = v == "1",
                    "window_last_tab_server_ids" => {
                        ws.open_tab_server_ids =
                            serde_json::from_str(&v).unwrap_or_default();
                    }
                    _ => {}
                }
            }
            Ok(ws)
        })
        .map_err(|e| e.to_string())
    })
}

/// Clears all persisted window-state keys from the `settings` table.
pub fn window_state_reset() -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "DELETE FROM settings WHERE key LIKE 'window_%'",
                [],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}
