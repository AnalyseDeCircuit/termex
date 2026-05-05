/// Git Sync API (v0.47 spec §7).
///
/// Provides status, enable/disable, manual trigger, multi-repo management.
/// Multi-repo rows persist to the V23 `git_sync_repos` table.  The actual
/// git invocation lives in `termex_core::git_sync` and is stubbed here.
use flutter_rust_bridge::frb;

use crate::db_state;

// ─── DTOs ────────────────────────────────────────────────────────────────────

#[frb]
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum GitSyncMode {
    Notify,
    Auto,
    Manual,
}

#[flutter_rust_bridge::frb(ignore)]
impl GitSyncMode {
    pub fn as_str(&self) -> &'static str {
        match self {
            GitSyncMode::Notify => "notify",
            GitSyncMode::Auto => "auto",
            GitSyncMode::Manual => "manual",
        }
    }

    pub fn from_str(s: &str) -> GitSyncMode {
        match s {
            "auto" => GitSyncMode::Auto,
            "manual" => GitSyncMode::Manual,
            _ => GitSyncMode::Notify,
        }
    }
}

#[frb]
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum GitSyncHealth {
    Synced,
    Pushing,
    Pulling,
    Conflict,
    Error,
    Disabled,
}

#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GitSyncStatus {
    pub server_id: String,
    pub enabled: bool,
    pub health: GitSyncHealth,
    pub mode: GitSyncMode,
    pub local_path: String,
    pub remote_url: String,
    pub last_sync_at: Option<String>,
    pub last_error: Option<String>,
    pub ahead: u32,
    pub behind: u32,
    pub conflicts: Vec<String>,
}

#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GitSyncRepo {
    pub id: String,
    pub server_id: String,
    pub local_path: String,
    pub remote_url: String,
    pub sync_mode: GitSyncMode,
    pub last_sync_at: Option<String>,
    pub last_error: Option<String>,
}

#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GitSyncInput {
    pub server_id: String,
    pub local_path: String,
    pub remote_url: String,
    pub sync_mode: GitSyncMode,
}

// ─── Status (single-repo, mirrors servers.git_sync_* columns) ───────────────

#[frb]
pub fn git_sync_status(server_id: String) -> Result<GitSyncStatus, String> {
    if !db_state::is_unlocked() {
        return Ok(GitSyncStatus {
            server_id,
            enabled: false,
            health: GitSyncHealth::Disabled,
            mode: GitSyncMode::Notify,
            local_path: String::new(),
            remote_url: String::new(),
            last_sync_at: None,
            last_error: None,
            ahead: 0,
            behind: 0,
            conflicts: vec![],
        });
    }

    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let row: Option<(i32, String, String, String, String)> = conn
                .query_row(
                    "SELECT COALESCE(git_sync_enabled, 0),
                            COALESCE(git_sync_mode, 'notify'),
                            COALESCE(git_sync_local_path, ''),
                            COALESCE(git_sync_remote_path, ''),
                            COALESCE(name, '')
                     FROM servers WHERE id = ?1",
                    rusqlite::params![server_id],
                    |r| {
                        Ok((
                            r.get::<_, i32>(0)?,
                            r.get::<_, String>(1)?,
                            r.get::<_, String>(2)?,
                            r.get::<_, String>(3)?,
                            r.get::<_, String>(4)?,
                        ))
                    },
                )
                .ok();

            match row {
                Some((enabled, mode, local_path, remote_url, _name)) => {
                    let enabled_bool = enabled != 0;
                    Ok(GitSyncStatus {
                        server_id: server_id.clone(),
                        enabled: enabled_bool,
                        health: if enabled_bool {
                            GitSyncHealth::Synced
                        } else {
                            GitSyncHealth::Disabled
                        },
                        mode: GitSyncMode::from_str(&mode),
                        local_path,
                        remote_url,
                        last_sync_at: None,
                        last_error: None,
                        ahead: 0,
                        behind: 0,
                        conflicts: vec![],
                    })
                }
                None => Ok(GitSyncStatus {
                    server_id: server_id.clone(),
                    enabled: false,
                    health: GitSyncHealth::Disabled,
                    mode: GitSyncMode::Notify,
                    local_path: String::new(),
                    remote_url: String::new(),
                    last_sync_at: None,
                    last_error: None,
                    ahead: 0,
                    behind: 0,
                    conflicts: vec![],
                }),
            }
        })
        .map_err(|e| e.to_string())
    })
}

#[frb]
pub fn git_sync_enable(
    server_id: String,
    remote: String,
    local_path: String,
) -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "UPDATE servers
                 SET git_sync_enabled = 1,
                     git_sync_remote_path = ?1,
                     git_sync_local_path = ?2
                 WHERE id = ?3",
                rusqlite::params![remote, local_path, server_id],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })?;
    let _ = crate::api::settings::audit_append(
        "git_sync.enable",
        &format!("server={server_id}"),
    );
    Ok(())
}

#[frb]
pub fn git_sync_disable(server_id: String) -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "UPDATE servers SET git_sync_enabled = 0 WHERE id = ?1",
                rusqlite::params![server_id],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })?;
    let _ = crate::api::settings::audit_append(
        "git_sync.disable",
        &format!("server={server_id}"),
    );
    Ok(())
}

#[frb]
pub fn git_sync_trigger(server_id: String) -> Result<GitSyncStatus, String> {
    // The actual `git fetch/merge/push` runs in `termex_core::git_sync`.  We
    // audit here and return the latest status read-back.
    let _ = crate::api::settings::audit_append(
        "git_sync.trigger",
        &format!("server={server_id}"),
    );
    git_sync_status(server_id)
}

// ─── Multi-repo (V23 git_sync_repos) ────────────────────────────────────────

#[frb]
pub fn git_sync_list_repos(server_id: String) -> Result<Vec<GitSyncRepo>, String> {
    if !db_state::is_unlocked() {
        return Ok(vec![]);
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, server_id, local_path, remote_url, sync_mode,
                        last_sync_at, last_error
                 FROM git_sync_repos WHERE server_id = ?1 ORDER BY created_at",
            )?;
            let iter = stmt.query_map(rusqlite::params![server_id], |r| {
                Ok(GitSyncRepo {
                    id: r.get(0)?,
                    server_id: r.get(1)?,
                    local_path: r.get(2)?,
                    remote_url: r.get(3)?,
                    sync_mode: GitSyncMode::from_str(&r.get::<_, String>(4)?),
                    last_sync_at: r.get(5)?,
                    last_error: r.get(6)?,
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

#[frb]
pub fn git_sync_add_repo(input: GitSyncInput) -> Result<String, String> {
    if !db_state::is_unlocked() {
        return Ok(uuid::Uuid::new_v4().to_string());
    }
    let id = uuid::Uuid::new_v4().to_string();
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let now = chrono::Utc::now().to_rfc3339();
            conn.execute(
                "INSERT INTO git_sync_repos
                   (id, server_id, local_path, remote_url, sync_mode, created_at, updated_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6)",
                rusqlite::params![
                    id,
                    input.server_id,
                    input.local_path,
                    input.remote_url,
                    input.sync_mode.as_str(),
                    now,
                ],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })?;
    Ok(id)
}

#[frb]
pub fn git_sync_remove_repo(id: String) -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "DELETE FROM git_sync_repos WHERE id = ?1",
                rusqlite::params![id],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

#[frb]
pub fn git_sync_update_repo_mode(id: String, mode: GitSyncMode) -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let now = chrono::Utc::now().to_rfc3339();
            conn.execute(
                "UPDATE git_sync_repos SET sync_mode = ?1, updated_at = ?2 WHERE id = ?3",
                rusqlite::params![mode.as_str(), now, id],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

#[frb]
pub fn git_sync_record_sync_result(
    id: String,
    error: Option<String>,
) -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let now = chrono::Utc::now().to_rfc3339();
            conn.execute(
                "UPDATE git_sync_repos
                 SET last_sync_at = ?1, last_error = ?2, updated_at = ?1
                 WHERE id = ?3",
                rusqlite::params![now, error, id],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}
