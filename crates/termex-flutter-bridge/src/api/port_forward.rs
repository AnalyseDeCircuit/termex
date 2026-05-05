/// Port-forwarding rule management exposed to Flutter via FRB (v0.47 spec §6).
///
/// Rules persist to the `port_forwards` table (V1 base + V23 bind_ip/auto_start_order).
/// Runtime status is tracked in a process-local in-memory registry.
///
/// When the database is not unlocked, rules live only in memory so the API
/// remains testable without a DB (backwards-compat with v0.46 behaviour).
use std::collections::HashMap;
use std::sync::Mutex;

use once_cell::sync::Lazy;

use crate::db_state;

// ─── DTOs ────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ForwardType {
    Local,
    Remote,
    Dynamic,
}

#[flutter_rust_bridge::frb(ignore)]
impl ForwardType {
    pub fn as_str(&self) -> &'static str {
        match self {
            ForwardType::Local => "local",
            ForwardType::Remote => "remote",
            ForwardType::Dynamic => "dynamic",
        }
    }

    pub fn from_str(s: &str) -> Option<ForwardType> {
        match s {
            "local" => Some(ForwardType::Local),
            "remote" => Some(ForwardType::Remote),
            "dynamic" => Some(ForwardType::Dynamic),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ForwardStatus {
    Stopped,
    Running,
    PortConflict(String),
    Error(String),
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ForwardRule {
    pub id: String,
    pub session_id: String,
    pub forward_type: ForwardType,
    pub bind_ip: String,
    pub local_port: u16,
    pub remote_host: String,
    pub remote_port: u16,
    pub is_active: bool,
    pub auto_start: bool,
}

// ─── Runtime registry ───────────────────────────────────────────────────────

static FORWARD_REGISTRY: Lazy<Mutex<HashMap<String, ForwardRule>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

/// Runtime status tracked separately from the persisted rule.
static STATUS_REGISTRY: Lazy<Mutex<HashMap<String, ForwardStatus>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

// ─── Conflict detection (§6.3) ──────────────────────────────────────────────

/// Returns `Some(port)` if `(bind_ip, port)` is already used by another rule
/// in either the persisted DB table or the runtime registry.
///
/// `exclude_id` takes `Option<String>` for Dart-compatibility (FRB cannot
/// auto-opaque an `Option<&str>`); all internal callers pass owned or cloned
/// strings anyway so the allocation cost is negligible.
pub fn port_forward_find_conflict(
    bind_ip: String,
    local_port: u16,
    exclude_id: Option<String>,
) -> Result<Option<String>, String> {
    let exclude_ref = exclude_id.as_deref();
    // Check in-memory first — cheapest.
    {
        let reg = FORWARD_REGISTRY.lock().unwrap();
        for (id, r) in reg.iter() {
            if Some(id.as_str()) == exclude_ref {
                continue;
            }
            if r.bind_ip == bind_ip && r.local_port == local_port {
                return Ok(Some(id.clone()));
            }
        }
    }

    // Check persisted rules.
    if db_state::is_unlocked() {
        let found: Option<String> = db_state::with_db(|db| {
            db.with_conn(|conn| {
                let rows: Vec<String> = {
                    let mut stmt = conn.prepare(
                        "SELECT id FROM port_forwards
                         WHERE COALESCE(bind_ip, '127.0.0.1') = ?1 AND local_port = ?2
                         LIMIT 1",
                    )?;
                    let iter = stmt.query_map(
                        rusqlite::params![bind_ip, local_port as i32],
                        |r| r.get::<_, String>(0),
                    )?;
                    iter.filter_map(|x| x.ok()).collect()
                };
                Ok(rows.into_iter().find(|id| Some(id.as_str()) != exclude_ref))
            })
            .map_err(|e| e.to_string())
        })?;
        return Ok(found);
    }

    Ok(None)
}

/// Scans `start..start+window` for a free port that does not conflict.
/// Returns the first free port or `None`.
pub fn port_forward_suggest_free_port(
    bind_ip: String,
    start: u16,
    window: u16,
) -> Result<Option<u16>, String> {
    for p in start..start.saturating_add(window) {
        if port_forward_find_conflict(bind_ip.clone(), p, None)?.is_none() {
            return Ok(Some(p));
        }
    }
    Ok(None)
}

// ─── CRUD ───────────────────────────────────────────────────────────────────

/// Creates + starts a new forwarding rule.  Returns the rule ID.
///
/// - Rejects reserved/already-bound `(bind_ip, local_port)` pairs.
/// - Rejects `0.0.0.0` bind unless `allow_lan = true`.
pub fn port_forward_start(
    session_id: String,
    forward_type: ForwardType,
    local_port: u16,
    remote_host: String,
    remote_port: u16,
) -> Result<String, String> {
    port_forward_start_ex(
        session_id,
        forward_type,
        "127.0.0.1".into(),
        local_port,
        remote_host,
        remote_port,
        false,
        false,
    )
}

#[allow(clippy::too_many_arguments)]
pub fn port_forward_start_ex(
    session_id: String,
    forward_type: ForwardType,
    bind_ip: String,
    local_port: u16,
    remote_host: String,
    remote_port: u16,
    auto_start: bool,
    allow_lan: bool,
) -> Result<String, String> {
    if bind_ip == "0.0.0.0" && !allow_lan {
        return Err("Binding to 0.0.0.0 requires explicit LAN opt-in".into());
    }
    if let Some(owner) = port_forward_find_conflict(bind_ip.clone(), local_port, None)? {
        return Err(format!(
            "Port {bind_ip}:{local_port} already bound by rule {owner}"
        ));
    }

    let id = uuid::Uuid::new_v4().to_string();
    let rule = ForwardRule {
        id: id.clone(),
        session_id: session_id.clone(),
        forward_type,
        bind_ip: bind_ip.clone(),
        local_port,
        remote_host: remote_host.clone(),
        remote_port,
        is_active: true,
        auto_start,
    };

    // Persist if DB is unlocked.
    if db_state::is_unlocked() {
        db_state::with_db(|db| {
            db.with_conn(|conn| {
                let now = chrono::Utc::now().to_rfc3339();
                conn.execute(
                    "INSERT INTO port_forwards
                       (id, server_id, forward_type, local_host, local_port, remote_host,
                        remote_port, auto_start, enabled, created_at, bind_ip)
                     VALUES (?1, ?2, ?3, '127.0.0.1', ?4, ?5, ?6, ?7, 1, ?8, ?9)",
                    rusqlite::params![
                        id,
                        session_id,
                        forward_type.as_str(),
                        local_port as i32,
                        remote_host,
                        remote_port as i32,
                        auto_start as i32,
                        now,
                        bind_ip,
                    ],
                )?;
                Ok(())
            })
            .map_err(|e| e.to_string())
        })?;
    }

    FORWARD_REGISTRY.lock().unwrap().insert(id.clone(), rule);
    STATUS_REGISTRY
        .lock()
        .unwrap()
        .insert(id.clone(), ForwardStatus::Running);

    Ok(id)
}

/// Stops and removes a port-forwarding rule by `rule_id`.
pub fn port_forward_stop(rule_id: String) -> Result<(), String> {
    FORWARD_REGISTRY.lock().unwrap().remove(&rule_id);
    STATUS_REGISTRY.lock().unwrap().remove(&rule_id);
    if db_state::is_unlocked() {
        db_state::with_db(|db| {
            db.with_conn(|conn| {
                conn.execute(
                    "DELETE FROM port_forwards WHERE id = ?1",
                    rusqlite::params![rule_id],
                )?;
                Ok(())
            })
            .map_err(|e| e.to_string())
        })?;
    }
    Ok(())
}

/// Pauses a rule (mark inactive) without deleting.
pub fn port_forward_disable(rule_id: String) -> Result<(), String> {
    if let Some(rule) = FORWARD_REGISTRY.lock().unwrap().get_mut(&rule_id) {
        rule.is_active = false;
    }
    STATUS_REGISTRY
        .lock()
        .unwrap()
        .insert(rule_id.clone(), ForwardStatus::Stopped);
    if db_state::is_unlocked() {
        db_state::with_db(|db| {
            db.with_conn(|conn| {
                conn.execute(
                    "UPDATE port_forwards SET enabled = 0 WHERE id = ?1",
                    rusqlite::params![rule_id],
                )?;
                Ok(())
            })
            .map_err(|e| e.to_string())
        })?;
    }
    Ok(())
}

/// Lists active port-forwarding rules for a specific `session_id`.
pub fn port_forward_list(session_id: String) -> Result<Vec<ForwardRule>, String> {
    // Runtime view first.
    let mem: Vec<ForwardRule> = FORWARD_REGISTRY
        .lock()
        .unwrap()
        .values()
        .filter(|r| r.session_id == session_id)
        .cloned()
        .collect();
    if !mem.is_empty() || !db_state::is_unlocked() {
        return Ok(mem);
    }

    // Fall back to DB view for rules persisted but not yet revived.
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, server_id, forward_type, local_port, COALESCE(remote_host, ''),
                        COALESCE(remote_port, 0), COALESCE(auto_start, 0),
                        COALESCE(enabled, 1), COALESCE(bind_ip, '127.0.0.1')
                 FROM port_forwards WHERE server_id = ?1",
            )?;
            let iter = stmt.query_map(rusqlite::params![session_id], |r| {
                Ok(ForwardRule {
                    id: r.get(0)?,
                    session_id: r.get(1)?,
                    forward_type: ForwardType::from_str(&r.get::<_, String>(2)?)
                        .unwrap_or(ForwardType::Local),
                    local_port: r.get::<_, i32>(3)? as u16,
                    remote_host: r.get(4)?,
                    remote_port: r.get::<_, i32>(5)? as u16,
                    auto_start: r.get::<_, i32>(6)? != 0,
                    is_active: r.get::<_, i32>(7)? != 0,
                    bind_ip: r.get(8)?,
                })
            })?;
            let mut out = Vec::new();
            for row in iter {
                if let Ok(r) = row {
                    out.push(r);
                }
            }
            Ok(out)
        })
        .map_err(|e| e.to_string())
    })
}

/// Lists all active port-forwarding rules across all sessions.
pub fn port_forward_list_all() -> Result<Vec<ForwardRule>, String> {
    let reg = FORWARD_REGISTRY.lock().unwrap();
    Ok(reg.values().cloned().collect())
}

/// Returns the status of `rule_id`, or `ForwardStatus::Stopped` if unknown.
pub fn port_forward_status(rule_id: String) -> ForwardStatus {
    STATUS_REGISTRY
        .lock()
        .unwrap()
        .get(&rule_id)
        .cloned()
        .unwrap_or(ForwardStatus::Stopped)
}

/// For tests: clears the forwarding registry.
pub fn _test_clear_registry() {
    FORWARD_REGISTRY.lock().unwrap().clear();
    STATUS_REGISTRY.lock().unwrap().clear();
}
