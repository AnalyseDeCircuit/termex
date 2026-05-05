/// Network proxy configuration exposed to Flutter via FRB (v0.47 spec §8).
///
/// Proxies persist to the `proxies` table (V6 base + V7 TLS + V9 command + V16 team).
/// The `proxy_password` value is NOT stored in SQLCipher; it lives in the OS
/// keychain under `proxy:{id}:password` (spec §8.6 Single-Prompt Rule).
///
/// Process-local in-memory registry is used as a fallback when the DB is not
/// yet unlocked (test mode).
use std::collections::HashMap;
use std::sync::Mutex;

use once_cell::sync::Lazy;

use crate::db_state;

// ─── DTOs ────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ProxyType {
    Socks5,
    Http,
    Tor,
}

#[flutter_rust_bridge::frb(ignore)]
impl ProxyType {
    pub fn as_str(&self) -> &'static str {
        match self {
            ProxyType::Socks5 => "socks5",
            ProxyType::Http => "http",
            ProxyType::Tor => "tor",
        }
    }

    pub fn from_str(s: &str) -> ProxyType {
        match s {
            "http" => ProxyType::Http,
            "tor" => ProxyType::Tor,
            _ => ProxyType::Socks5,
        }
    }
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProxyConfig {
    pub id: String,
    pub proxy_type: ProxyType,
    pub host: String,
    pub port: u16,
    pub username: Option<String>,
    pub is_default: bool,
    pub tls_enabled: bool,
    pub health_ms: Option<u32>,
    pub name: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TorStatus {
    pub running: bool,
    pub bootstrap_percent: u8,
    pub socks_port: Option<u16>,
    pub circuits_count: u32,
    pub last_error: Option<String>,
}

// ─── Registry ───────────────────────────────────────────────────────────────

static PROXY_REGISTRY: Lazy<Mutex<HashMap<String, ProxyConfig>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

static TOR_STATE: Lazy<Mutex<TorStatus>> = Lazy::new(|| {
    Mutex::new(TorStatus {
        running: false,
        bootstrap_percent: 0,
        socks_port: None,
        circuits_count: 0,
        last_error: None,
    })
});

// ─── CRUD ───────────────────────────────────────────────────────────────────

pub fn proxy_list() -> Result<Vec<ProxyConfig>, String> {
    // In-memory view first.
    let mem = PROXY_REGISTRY.lock().unwrap();
    if !mem.is_empty() || !db_state::is_unlocked() {
        return Ok(mem.values().cloned().collect());
    }
    drop(mem);

    // Otherwise load from DB.
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, COALESCE(name, ''), proxy_type, host, port, username,
                        COALESCE(tls_enabled, 0)
                 FROM proxies ORDER BY created_at",
            )?;
            let iter = stmt.query_map([], |r| {
                Ok(ProxyConfig {
                    id: r.get(0)?,
                    name: r.get(1)?,
                    proxy_type: ProxyType::from_str(&r.get::<_, String>(2)?),
                    host: r.get(3)?,
                    port: r.get::<_, i32>(4)? as u16,
                    username: r.get(5)?,
                    is_default: false,
                    tls_enabled: r.get::<_, i32>(6)? != 0,
                    health_ms: None,
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

/// Creates a new proxy configuration.  If `password` is `Some`, the caller is
/// responsible for also persisting it to the OS keychain at
/// `proxy:{id}:password` — the FRB layer intentionally does not store plain
/// passwords anywhere.
pub fn proxy_create(
    proxy_type: ProxyType,
    host: String,
    port: u16,
    username: Option<String>,
) -> Result<ProxyConfig, String> {
    proxy_create_ex(String::new(), proxy_type, host, port, username, false)
}

pub fn proxy_create_ex(
    name: String,
    proxy_type: ProxyType,
    host: String,
    port: u16,
    username: Option<String>,
    tls_enabled: bool,
) -> Result<ProxyConfig, String> {
    let id = uuid::Uuid::new_v4().to_string();
    let config = ProxyConfig {
        id: id.clone(),
        proxy_type,
        host: host.clone(),
        port,
        username: username.clone(),
        is_default: false,
        tls_enabled,
        health_ms: None,
        name: name.clone(),
    };

    if db_state::is_unlocked() {
        db_state::with_db(|db| {
            db.with_conn(|conn| {
                let now = chrono::Utc::now().to_rfc3339();
                conn.execute(
                    "INSERT INTO proxies
                       (id, name, proxy_type, host, port, username,
                        tls_enabled, created_at, updated_at)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?8)",
                    rusqlite::params![
                        id,
                        if name.is_empty() { format!("{} {}:{}", proxy_type.as_str(), host, port) } else { name },
                        proxy_type.as_str(),
                        host,
                        port as i32,
                        username,
                        tls_enabled as i32,
                        now,
                    ],
                )?;
                Ok(())
            })
            .map_err(|e| e.to_string())
        })?;
    }

    PROXY_REGISTRY.lock().unwrap().insert(id, config.clone());
    Ok(config)
}

pub fn proxy_delete(id: String) -> Result<(), String> {
    PROXY_REGISTRY.lock().unwrap().remove(&id);
    if db_state::is_unlocked() {
        db_state::with_db(|db| {
            db.with_conn(|conn| {
                conn.execute(
                    "DELETE FROM proxies WHERE id = ?1",
                    rusqlite::params![id],
                )?;
                Ok(())
            })
            .map_err(|e| e.to_string())
        })?;
    }
    Ok(())
}

pub fn proxy_set_default(id: String) -> Result<(), String> {
    let mut reg = PROXY_REGISTRY.lock().unwrap();
    for config in reg.values_mut() {
        config.is_default = false;
    }
    if let Some(config) = reg.get_mut(&id) {
        config.is_default = true;
        Ok(())
    } else if db_state::is_unlocked() {
        // Rehydrate from DB into registry before marking default.
        drop(reg);
        let all = proxy_list()?;
        let mut reg = PROXY_REGISTRY.lock().unwrap();
        for c in all {
            reg.entry(c.id.clone()).or_insert(c);
        }
        if let Some(c) = reg.get_mut(&id) {
            c.is_default = true;
            Ok(())
        } else {
            Err(format!("Proxy '{id}' not found"))
        }
    } else {
        Err(format!("Proxy '{id}' not found"))
    }
}

pub fn proxy_get_default() -> Result<Option<ProxyConfig>, String> {
    let reg = PROXY_REGISTRY.lock().unwrap();
    Ok(reg.values().find(|c| c.is_default).cloned())
}

pub fn proxy_test_connection(id: String) -> Result<bool, String> {
    let _ = id;
    Ok(false)
}

/// Returns the canonical keychain key used to store `proxy_id`'s password.
pub fn proxy_keychain_key(proxy_id: &str) -> String {
    format!("proxy:{}:password", proxy_id)
}

/// Updates (or inserts) a cached health latency for `proxy_id`.  Called by
/// the background health-check job.
pub fn proxy_record_health(proxy_id: String, latency_ms: Option<u32>) {
    if let Some(c) = PROXY_REGISTRY.lock().unwrap().get_mut(&proxy_id) {
        c.health_ms = latency_ms;
    }
}

// ─── Tor ────────────────────────────────────────────────────────────────────

pub fn tor_start() -> Result<u16, String> {
    let mut st = TOR_STATE.lock().unwrap();
    if st.running {
        return st.socks_port.ok_or_else(|| "Tor already running but no port".into());
    }
    st.running = true;
    st.bootstrap_percent = 100;
    st.socks_port = Some(9150);
    st.circuits_count = 1;
    st.last_error = None;
    Ok(9150)
}

pub fn tor_stop() -> Result<(), String> {
    let mut st = TOR_STATE.lock().unwrap();
    st.running = false;
    st.bootstrap_percent = 0;
    st.socks_port = None;
    st.circuits_count = 0;
    Ok(())
}

pub fn tor_status() -> TorStatus {
    TOR_STATE.lock().unwrap().clone()
}

/// For tests: clears the proxy registry and tor state.
pub fn _test_clear_registry() {
    PROXY_REGISTRY.lock().unwrap().clear();
    let mut st = TOR_STATE.lock().unwrap();
    st.running = false;
    st.bootstrap_percent = 0;
    st.socks_port = None;
    st.circuits_count = 0;
    st.last_error = None;
}
