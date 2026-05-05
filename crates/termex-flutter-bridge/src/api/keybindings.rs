/// Keyboard shortcut management exposed to Flutter via FRB.
///
/// User overrides persist to the `keybindings` table (Migration V22).  When
/// the database is not unlocked the registry falls back to a process-local
/// in-memory map so unit tests can exercise the registry API shape.
use std::collections::HashMap;
use std::sync::Mutex;

use once_cell::sync::Lazy;

use crate::db_state;

// ─── DTOs ────────────────────────────────────────────────────────────────────

/// A single keyboard shortcut binding.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KeybindingEntry {
    pub action: String,
    pub key_combination: String,
    /// One of `"global"`, `"terminal"`, or `"sftp"`.
    pub context: String,
}

/// Describes a conflict with an existing keybinding.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConflictInfo {
    pub action: String,
    pub key_combination: String,
}

// ─── Registry ─────────────────────────────────────────────────────────────────

/// In-memory fallback for when the database is not unlocked.
static KEYBINDING_REGISTRY: Lazy<Mutex<HashMap<String, KeybindingEntry>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

// ─── Functions ────────────────────────────────────────────────────────────────

/// Returns the effective keybindings: user overrides merged on top of defaults.
pub fn keybinding_list() -> Result<Vec<KeybindingEntry>, String> {
    let overrides = load_overrides()?;
    let mut map: HashMap<String, KeybindingEntry> = keybinding_get_defaults()
        .into_iter()
        .map(|e| (e.action.clone(), e))
        .collect();
    for (action, entry) in overrides {
        map.insert(action, entry);
    }
    Ok(map.into_values().collect())
}

/// Sets a custom key combination for `action`.
pub fn keybinding_set(
    action: String,
    key_combination: String,
    context: String,
) -> Result<(), String> {
    let entry = KeybindingEntry {
        action: action.clone(),
        key_combination: key_combination.clone(),
        context: context.clone(),
    };

    if db_state::is_unlocked() {
        db_state::with_db(|db| {
            db.with_conn(|conn| {
                let now = chrono::Utc::now().to_rfc3339();
                conn.execute(
                    "INSERT INTO keybindings (action, key_combination, context, updated_at)
                     VALUES (?1, ?2, ?3, ?4)
                     ON CONFLICT(action) DO UPDATE SET
                         key_combination = excluded.key_combination,
                         context         = excluded.context,
                         updated_at      = excluded.updated_at",
                    rusqlite::params![action, key_combination, context, now],
                )?;
                Ok(())
            })
            .map_err(|e| e.to_string())
        })
    } else {
        KEYBINDING_REGISTRY.lock().unwrap().insert(action, entry);
        Ok(())
    }
}

/// Resets a single action's binding to its default (removes user override).
pub fn keybinding_reset(action: String) -> Result<(), String> {
    if db_state::is_unlocked() {
        db_state::with_db(|db| {
            db.with_conn(|conn| {
                conn.execute(
                    "DELETE FROM keybindings WHERE action = ?1",
                    rusqlite::params![action],
                )?;
                Ok(())
            })
            .map_err(|e| e.to_string())
        })
    } else {
        KEYBINDING_REGISTRY.lock().unwrap().remove(&action);
        Ok(())
    }
}

/// Resets all keybindings to their defaults by clearing all user overrides.
pub fn keybinding_reset_all() -> Result<(), String> {
    if db_state::is_unlocked() {
        db_state::with_db(|db| {
            db.with_conn(|conn| {
                conn.execute("DELETE FROM keybindings", [])?;
                Ok(())
            })
            .map_err(|e| e.to_string())
        })
    } else {
        KEYBINDING_REGISTRY.lock().unwrap().clear();
        Ok(())
    }
}

/// Checks whether `key_combination` in `context` conflicts with an existing binding.
///
/// A conflict exists when the same combination is already used by a *different* action
/// in the same context or in the `"global"` context.  Returns the conflicting action's
/// info, or `None` if no conflict exists.
pub fn keybinding_check_conflict(
    key_combination: String,
    context: String,
) -> Result<Option<ConflictInfo>, String> {
    // Check persisted overrides first (they are the effective bindings when set).
    let overrides = load_overrides()?;
    for entry in overrides.values() {
        if is_conflict(entry, &key_combination, &context) {
            return Ok(Some(ConflictInfo {
                action: entry.action.clone(),
                key_combination: entry.key_combination.clone(),
            }));
        }
    }
    // Fall back to defaults.
    let defaults = keybinding_get_defaults();
    for entry in &defaults {
        if overrides.contains_key(&entry.action) {
            continue; // Already checked via overrides.
        }
        if is_conflict(entry, &key_combination, &context) {
            return Ok(Some(ConflictInfo {
                action: entry.action.clone(),
                key_combination: entry.key_combination.clone(),
            }));
        }
    }
    Ok(None)
}

fn is_conflict(entry: &KeybindingEntry, key_combination: &str, context: &str) -> bool {
    let same_context = entry.context == context
        || entry.context == "global"
        || context == "global";
    same_context && entry.key_combination == key_combination
}

fn load_overrides() -> Result<HashMap<String, KeybindingEntry>, String> {
    if db_state::is_unlocked() {
        db_state::with_db(|db| {
            db.with_conn(|conn| {
                let mut stmt = conn
                    .prepare("SELECT action, key_combination, context FROM keybindings")?;
                let iter = stmt.query_map([], |r| {
                    Ok(KeybindingEntry {
                        action: r.get(0)?,
                        key_combination: r.get(1)?,
                        context: r.get(2)?,
                    })
                })?;
                let mut out = HashMap::new();
                for row in iter {
                    let e = row?;
                    out.insert(e.action.clone(), e);
                }
                Ok(out)
            })
            .map_err(|e| e.to_string())
        })
    } else {
        Ok(KEYBINDING_REGISTRY.lock().unwrap().clone())
    }
}

/// Returns the hardcoded default keybindings shipped with Termex.
pub fn keybinding_get_defaults() -> Vec<KeybindingEntry> {
    vec![
        KeybindingEntry { action: "new_tab".into(),           key_combination: "⌘T".into(),       context: "global".into() },
        KeybindingEntry { action: "close_tab".into(),         key_combination: "⌘W".into(),       context: "global".into() },
        KeybindingEntry { action: "search_terminal".into(),   key_combination: "⌘F".into(),       context: "terminal".into() },
        KeybindingEntry { action: "split_horizontal".into(),  key_combination: "⌘D".into(),       context: "terminal".into() },
        KeybindingEntry { action: "split_vertical".into(),    key_combination: "⌘Shift+D".into(), context: "terminal".into() },
        KeybindingEntry { action: "ai_panel".into(),          key_combination: "⌘J".into(),       context: "global".into() },
        KeybindingEntry { action: "focus_next_pane".into(),   key_combination: "⌘]".into(),       context: "terminal".into() },
        KeybindingEntry { action: "focus_prev_pane".into(),   key_combination: "⌘[".into(),       context: "terminal".into() },
        KeybindingEntry { action: "toggle_sftp".into(),       key_combination: "⌘Shift+S".into(), context: "global".into() },
        KeybindingEntry { action: "copy".into(),              key_combination: "⌘C".into(),       context: "terminal".into() },
        KeybindingEntry { action: "paste".into(),             key_combination: "⌘V".into(),       context: "terminal".into() },
        KeybindingEntry { action: "select_all".into(),        key_combination: "⌘A".into(),       context: "terminal".into() },
        KeybindingEntry { action: "zoom_in".into(),           key_combination: "⌘=".into(),       context: "terminal".into() },
        KeybindingEntry { action: "zoom_out".into(),          key_combination: "⌘-".into(),       context: "terminal".into() },
        KeybindingEntry { action: "reset_zoom".into(),        key_combination: "⌘0".into(),       context: "terminal".into() },
    ]
}

/// For tests: clears the in-memory registry.  Database-backed overrides are
/// unaffected — integration tests that use the database must rely on the
/// per-test temp-directory isolation.
pub fn _test_clear_registry() {
    KEYBINDING_REGISTRY.lock().unwrap().clear();
}

// ─── Scopes ─────────────────────────────────────────────────────────────────

/// All five valid keybinding scopes defined by v0.46 spec §4.4.5.
pub const SCOPE_GLOBAL: &str = "global";
pub const SCOPE_TERMINAL: &str = "terminal";
pub const SCOPE_SFTP: &str = "sftp";
pub const SCOPE_AI_PANEL: &str = "ai_panel";
pub const SCOPE_MONITOR: &str = "monitor";

pub const ALL_SCOPES: &[&str] =
    &[SCOPE_GLOBAL, SCOPE_TERMINAL, SCOPE_SFTP, SCOPE_AI_PANEL, SCOPE_MONITOR];

/// Returns the canonical list of valid scope names.
pub fn keybinding_list_scopes() -> Vec<String> {
    ALL_SCOPES.iter().map(|s| s.to_string()).collect()
}

/// Returns `true` if the scope is recognised.
pub fn keybinding_is_valid_scope(scope: &str) -> bool {
    ALL_SCOPES.contains(&scope)
}

// ─── System reserved keys ───────────────────────────────────────────────────

/// Key combinations that must not be user-bindable because the OS or WM
/// always intercepts them.  Per v0.46 spec §4.4.5.
pub const RESERVED_KEYS: &[&str] = &[
    "⌘Tab",
    "⌘Space",
    "⌘Q",
    "⌘H",
    "⌘M",
    "Alt+F4",
    "Ctrl+Alt+Del",
    "Ctrl+Alt+Delete",
    "Super+Tab",
];

/// Returns `true` if `key_combination` is a system-reserved shortcut and must
/// not be overridden.
pub fn keybinding_is_reserved(key_combination: &str) -> bool {
    RESERVED_KEYS.contains(&key_combination)
}

/// Lists every system-reserved key combination.  Used by the UI to populate
/// a warning banner in the keybinding editor.
pub fn keybinding_list_reserved_keys() -> Vec<String> {
    RESERVED_KEYS.iter().map(|s| s.to_string()).collect()
}

/// Like `keybinding_set`, but rejects system-reserved combinations up-front.
pub fn keybinding_set_validated(
    action: String,
    key_combination: String,
    context: String,
) -> Result<(), String> {
    if keybinding_is_reserved(&key_combination) {
        return Err(format!(
            "Key combination '{}' is reserved by the system and cannot be rebound",
            key_combination
        ));
    }
    if !keybinding_is_valid_scope(&context) {
        return Err(format!("Unknown scope '{}'", context));
    }
    keybinding_set(action, key_combination, context)
}
