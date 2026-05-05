use crate::db_state;
use termex_core::keychain;
use termex_core::storage::models;
use chrono::Utc;
use uuid::Uuid;

// ============================================================
// Auth type
// ============================================================

/// Auth type exposed to Flutter — superset of core AuthType.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum AuthType {
    Password,
    Key,
    Agent,
    Interactive,
}

#[flutter_rust_bridge::frb(ignore)]
impl AuthType {
    fn to_core(&self) -> models::AuthType {
        match self {
            Self::Password | Self::Interactive => models::AuthType::Password,
            Self::Key | Self::Agent => models::AuthType::Key,
        }
    }

    fn from_core(a: &models::AuthType) -> Self {
        match a {
            models::AuthType::Password => Self::Password,
            models::AuthType::Key => Self::Key,
        }
    }

    fn as_str(&self) -> &'static str {
        match self {
            Self::Password => "password",
            Self::Key => "key",
            Self::Agent => "agent",
            Self::Interactive => "interactive",
        }
    }

    fn from_str(s: &str) -> Self {
        match s {
            "key" => Self::Key,
            "agent" => Self::Agent,
            "interactive" => Self::Interactive,
            _ => Self::Password,
        }
    }
}

// ============================================================
// DTOs
// ============================================================

/// Lightweight server DTO for Flutter.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServerDto {
    pub id: String,
    pub name: String,
    pub host: String,
    pub port: u16,
    pub username: String,
    pub auth_type: AuthType,
    pub key_path: Option<String>,
    pub group_id: Option<String>,
    pub sort_order: i32,
    pub tags: Vec<String>,
    pub last_connected: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

/// Input for creating or editing a server.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServerInput {
    pub name: String,
    pub host: String,
    pub port: u16,
    pub username: String,
    pub auth_type: AuthType,
    pub password: Option<String>,
    pub key_path: Option<String>,
    pub group_id: Option<String>,
    pub tags: Vec<String>,
}

/// Quick connect history entry.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QuickConnectEntry {
    pub id: String,
    pub host: String,
    pub port: u16,
    pub username: String,
    pub used_at: String,
}

// ============================================================
// Internal helpers
// ============================================================

fn row_to_dto(
    id: String,
    name: String,
    host: String,
    port: i64,
    username: String,
    auth_type_str: String,
    key_path: Option<String>,
    group_id: Option<String>,
    sort_order: i64,
    tags_json: Option<String>,
    last_connected: Option<String>,
    created_at: String,
    updated_at: String,
) -> ServerDto {
    let auth_type = AuthType::from_str(&auth_type_str);
    let tags: Vec<String> = tags_json
        .and_then(|j| serde_json::from_str(&j).ok())
        .unwrap_or_default();
    ServerDto {
        id,
        name,
        host,
        port: port as u16,
        username,
        auth_type,
        key_path,
        group_id,
        sort_order: sort_order as i32,
        tags,
        last_connected,
        created_at,
        updated_at,
    }
}

// ============================================================
// Public API
// ============================================================

/// List all servers ordered by sort_order then name.
pub fn list_servers() -> Result<Vec<ServerDto>, String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, host, port, username, auth_type, key_path, group_id,
                        sort_order, tags, last_connected, created_at, updated_at
                 FROM servers
                 ORDER BY sort_order, name",
            )?;
            let rows = stmt.query_map([], |row| {
                Ok(row_to_dto(
                    row.get(0)?,
                    row.get(1)?,
                    row.get(2)?,
                    row.get(3)?,
                    row.get(4)?,
                    row.get(5)?,
                    row.get(6)?,
                    row.get(7)?,
                    row.get(8)?,
                    row.get(9)?,
                    row.get(10)?,
                    row.get(11)?,
                    row.get(12)?,
                ))
            })?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
        .map_err(|e| e.to_string())
    })
}

/// Retrieve a single server by ID.
pub fn get_server(id: String) -> Result<Option<ServerDto>, String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, host, port, username, auth_type, key_path, group_id,
                        sort_order, tags, last_connected, created_at, updated_at
                 FROM servers WHERE id = ?1",
            )?;
            let mut rows = stmt.query_map([&id], |row| {
                Ok(row_to_dto(
                    row.get(0)?,
                    row.get(1)?,
                    row.get(2)?,
                    row.get(3)?,
                    row.get(4)?,
                    row.get(5)?,
                    row.get(6)?,
                    row.get(7)?,
                    row.get(8)?,
                    row.get(9)?,
                    row.get(10)?,
                    row.get(11)?,
                    row.get(12)?,
                ))
            })?;
            match rows.next() {
                Some(row) => Ok(Some(row?)),
                None => Ok(None),
            }
        })
        .map_err(|e| e.to_string())
    })
}

/// Create a new server entry, storing password in keychain if provided.
pub fn create_server(input: ServerInput) -> Result<ServerDto, String> {
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();
    let tags_json = serde_json::to_string(&input.tags).map_err(|e| e.to_string())?;
    let auth_str = input.auth_type.as_str().to_string();

    // Store password in keychain (not in DB)
    if let Some(ref pw) = input.password {
        if !pw.is_empty() {
            let key = format!("termex:ssh:password:{id}");
            keychain::store(&key, pw).map_err(|e| e.to_string())?;
        }
    }

    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "INSERT INTO servers
                    (id, name, host, port, username, auth_type, key_path, group_id,
                     sort_order, tags, created_at, updated_at)
                 VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12)",
                rusqlite::params![
                    id,
                    input.name,
                    input.host,
                    input.port as i64,
                    input.username,
                    auth_str,
                    input.key_path,
                    input.group_id,
                    0i64,
                    tags_json,
                    now,
                    now,
                ],
            )?;
            Ok(ServerDto {
                id: id.clone(),
                name: input.name.clone(),
                host: input.host.clone(),
                port: input.port,
                username: input.username.clone(),
                auth_type: input.auth_type.clone(),
                key_path: input.key_path.clone(),
                group_id: input.group_id.clone(),
                sort_order: 0,
                tags: input.tags.clone(),
                last_connected: None,
                created_at: now.clone(),
                updated_at: now,
            })
        })
        .map_err(|e| e.to_string())
    })
}

/// Update an existing server, refreshing keychain entry for password.
pub fn update_server(id: String, input: ServerInput) -> Result<ServerDto, String> {
    let now = Utc::now().to_rfc3339();
    let tags_json = serde_json::to_string(&input.tags).map_err(|e| e.to_string())?;
    let auth_str = input.auth_type.as_str().to_string();

    // Update keychain entry if password provided
    if let Some(ref pw) = input.password {
        if !pw.is_empty() {
            let key = format!("termex:ssh:password:{id}");
            keychain::store(&key, pw).map_err(|e| e.to_string())?;
        }
    }

    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "UPDATE servers SET name=?2, host=?3, port=?4, username=?5, auth_type=?6,
                          key_path=?7, group_id=?8, tags=?9, updated_at=?10
                 WHERE id=?1",
                rusqlite::params![
                    id,
                    input.name,
                    input.host,
                    input.port as i64,
                    input.username,
                    auth_str,
                    input.key_path,
                    input.group_id,
                    tags_json,
                    now,
                ],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })?;

    // Return updated record
    get_server(id.clone())?.ok_or_else(|| format!("server not found after update: {id}"))
}

/// Delete a server by ID.
pub fn delete_server(id: String) -> Result<(), String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute("DELETE FROM servers WHERE id=?1", rusqlite::params![id])?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Move a server to a different group (or un-group it).
pub fn move_server_to_group(id: String, group_id: Option<String>) -> Result<(), String> {
    let now = Utc::now().to_rfc3339();
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "UPDATE servers SET group_id=?2, updated_at=?3 WHERE id=?1",
                rusqlite::params![id, group_id, now],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Update the last_connected timestamp for a server to now.
pub fn update_last_connected(id: String) -> Result<(), String> {
    let now = Utc::now().to_rfc3339();
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "UPDATE servers SET last_connected=?2 WHERE id=?1",
                rusqlite::params![id, now],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

// ============================================================
// Quick connect history
// ============================================================

/// List quick connect history, newest first, capped at 20 entries.
pub fn list_quick_connect_history() -> Result<Vec<QuickConnectEntry>, String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, host, port, username, used_at
                 FROM quick_connect_history
                 ORDER BY used_at DESC LIMIT 20",
            )?;
            let rows = stmt.query_map([], |row| {
                Ok(QuickConnectEntry {
                    id: row.get(0)?,
                    host: row.get(1)?,
                    port: row.get::<_, i64>(2)? as u16,
                    username: row.get(3)?,
                    used_at: row.get(4)?,
                })
            })?;
            let mut out = Vec::new();
            for row in rows {
                out.push(row?);
            }
            Ok(out)
        })
        .map_err(|e| e.to_string())
    })
}

/// Add an entry to quick connect history and prune entries beyond the most recent 20.
pub fn add_quick_connect_history(host: String, port: u16, username: String) -> Result<(), String> {
    let id = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "INSERT INTO quick_connect_history (id, host, port, username, used_at)
                 VALUES (?1,?2,?3,?4,?5)",
                rusqlite::params![id, host, port as i64, username, now],
            )?;
            // Keep only the 20 most recent entries
            conn.execute(
                "DELETE FROM quick_connect_history
                 WHERE id NOT IN (
                     SELECT id FROM quick_connect_history
                     ORDER BY used_at DESC LIMIT 20
                 )",
                [],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Clear all quick connect history.
pub fn clear_quick_connect_history() -> Result<(), String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute("DELETE FROM quick_connect_history", [])?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}
