use std::collections::{HashMap, HashSet};
use std::path::Path;

use rusqlite::Connection;

use super::crypto::{team_decrypt, team_encrypt, TeamCryptoError};
use super::types::{
    default_preset_roles, ConflictItem, ConflictResolution, ConflictStrategy,
    SharedCloudFavorite, SharedGroups, SharedProxy, SharedRecording,
    SharedServerConfig, SharedSnippet, TeamJson,
};

/// Sync error types.
#[derive(Debug, thiserror::Error)]
pub enum TeamSyncError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("crypto error: {0}")]
    Crypto(#[from] TeamCryptoError),
    #[error("database error: {0}")]
    Db(String),
    #[error("team.json not found")]
    NoTeamJson,
}

/// Merge decision for LWW conflict resolution.
#[derive(Debug, PartialEq)]
pub enum MergeDecision {
    /// Remote is newer — import into local DB.
    ImportRemote,
    /// Local is newer — export to repo file.
    ExportLocal,
    /// Same timestamp — no action needed.
    NoAction,
}

/// Compares timestamps to decide which version wins (Last Writer Wins).
pub fn merge_decision(local_updated_at: Option<&str>, remote_updated_at: &str) -> MergeDecision {
    match local_updated_at {
        None => MergeDecision::ImportRemote,
        Some(local_ts) => {
            if remote_updated_at > local_ts {
                MergeDecision::ImportRemote
            } else if local_ts > remote_updated_at {
                MergeDecision::ExportLocal
            } else {
                MergeDecision::NoAction
            }
        }
    }
}

/// Migrates team.json from v1 (admin/member/readonly) to v2 (capability-based roles).
pub fn migrate_v1_to_v2(team: &mut TeamJson) -> bool {
    if team.version >= 2 {
        return false;
    }
    for member in &mut team.members {
        member.role = match member.role.as_str() {
            "admin" => "admin".to_string(),
            "member" => "ops".to_string(),
            "readonly" => "viewer".to_string(),
            other => other.to_string(),
        };
    }
    team.roles = default_preset_roles();
    team.role_overrides = HashMap::new();
    team.version = 2;
    true
}

/// Reads and parses team.json from the repo, auto-migrating v1→v2 in memory.
pub fn read_team_json(repo_path: &Path) -> Result<TeamJson, TeamSyncError> {
    let path = repo_path.join("team.json");
    if !path.exists() {
        return Err(TeamSyncError::NoTeamJson);
    }
    let content = std::fs::read_to_string(&path)?;
    let mut team: TeamJson = serde_json::from_str(&content)?;

    // Ensure roles are populated even for v2 files with empty roles map
    if team.roles.is_empty() {
        team.roles = default_preset_roles();
    }

    migrate_v1_to_v2(&mut team);
    Ok(team)
}

/// Writes team.json to the repo.
pub fn write_team_json(repo_path: &Path, team: &TeamJson) -> Result<(), TeamSyncError> {
    let path = repo_path.join("team.json");
    let json = serde_json::to_string_pretty(team)?;
    std::fs::write(path, json)?;
    Ok(())
}

/// Imports servers from repo into local DB using LWW merge.
///
/// Returns the number of servers imported (inserted or updated).
pub fn import_remote_servers(
    conn: &Connection,
    repo_path: &Path,
    team_key: &[u8; 32],
    team_id: &str,
) -> Result<usize, TeamSyncError> {
    let servers_dir = repo_path.join("servers");
    if !servers_dir.exists() {
        return Ok(0);
    }

    let mut imported = 0;
    for entry in std::fs::read_dir(&servers_dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.extension().map(|e| e == "json").unwrap_or(false) {
            let content = std::fs::read_to_string(&path)?;
            let remote: SharedServerConfig = serde_json::from_str(&content)?;

            // Check if local exists and compare timestamps
            let local_updated = get_server_updated_at(conn, &remote.id);
            let decision = merge_decision(local_updated.as_deref(), &remote.updated_at);

            if decision == MergeDecision::ImportRemote {
                import_single_server(conn, &remote, team_key, team_id)?;
                imported += 1;
            }
        }
    }

    Ok(imported)
}

/// Exports locally shared servers to the repo as JSON files.
///
/// Returns the number of servers exported.
pub fn export_local_shared(
    conn: &Connection,
    repo_path: &Path,
    team_key: &[u8; 32],
    username: &str,
) -> Result<usize, TeamSyncError> {
    let servers_dir = repo_path.join("servers");
    std::fs::create_dir_all(&servers_dir)?;

    let mut exported = 0;

    let mut stmt = conn
        .prepare(
            "SELECT id, name, host, port, username, auth_type,
                    password_keychain_id, passphrase_keychain_id,
                    group_id, startup_cmd, encoding, auto_record,
                    shared_by, shared_at, updated_at
             FROM servers WHERE shared = 1",
        )
        .map_err(|e| TeamSyncError::Db(e.to_string()))?;

    let rows: Vec<SharedServerExportRow> = stmt
        .query_map([], |row| {
            Ok(SharedServerExportRow {
                id: row.get(0)?,
                name: row.get(1)?,
                host: row.get(2)?,
                port: row.get(3)?,
                username: row.get(4)?,
                auth_type: row.get(5)?,
                password_keychain_id: row.get(6)?,
                passphrase_keychain_id: row.get(7)?,
                group_id: row.get(8)?,
                startup_cmd: row.get(9)?,
                encoding: row.get(10)?,
                auto_record: row.get::<_, i32>(11)? != 0,
                shared_by: row.get(12)?,
                shared_at: row.get(13)?,
                updated_at: row.get(14)?,
            })
        })
        .map_err(|e| TeamSyncError::Db(e.to_string()))?
        .filter_map(|r| r.ok())
        .collect();

    for row in &rows {
        // Check if repo file exists and compare timestamps
        let file_path = servers_dir.join(format!("{}.json", row.id));
        let remote_ts = if file_path.exists() {
            let content = std::fs::read_to_string(&file_path)?;
            let remote: SharedServerConfig = serde_json::from_str(&content)?;
            Some(remote.updated_at)
        } else {
            None
        };

        let decision = merge_decision(remote_ts.as_deref(), &row.updated_at);
        if decision == MergeDecision::ImportRemote || remote_ts.is_none() {
            // Local is newer or file doesn't exist — export
            let password_enc = row
                .password_keychain_id
                .as_deref()
                .and_then(|kid| crate::keychain::get(kid).ok())
                .map(|pwd| team_encrypt(team_key, &pwd))
                .transpose()?;

            let passphrase_enc = row
                .passphrase_keychain_id
                .as_deref()
                .and_then(|kid| crate::keychain::get(kid).ok())
                .map(|pp| team_encrypt(team_key, &pp))
                .transpose()?;

            let config = SharedServerConfig {
                id: row.id.clone(),
                name: row.name.clone(),
                host: row.host.clone(),
                port: row.port,
                username: row.username.clone(),
                auth_type: row.auth_type.clone(),
                password_enc,
                passphrase_enc,
                group_id: row.group_id.clone(),
                tags: String::new(),
                startup_cmd: row.startup_cmd.clone(),
                encoding: row.encoding.clone(),
                auto_record: row.auto_record,
                shared_by: row.shared_by.clone().unwrap_or_else(|| username.to_string()),
                shared_at: row.shared_at.clone().unwrap_or_else(now_rfc3339),
                updated_at: row.updated_at.clone(),
            };

            let json = serde_json::to_string_pretty(&config)?;
            std::fs::write(&file_path, json)?;
            exported += 1;
        }
    }

    Ok(exported)
}

/// Detects servers that were deleted from the remote repo.
///
/// Returns the number of servers deleted locally.
pub fn detect_remote_deletions(
    conn: &Connection,
    repo_path: &Path,
    team_id: &str,
) -> Result<usize, TeamSyncError> {
    let servers_dir = repo_path.join("servers");

    // Get all server IDs in the repo
    let mut remote_ids = HashSet::new();
    if servers_dir.exists() {
        for entry in std::fs::read_dir(&servers_dir)? {
            let entry = entry?;
            let path = entry.path();
            if let Some(stem) = path.file_stem() {
                remote_ids.insert(stem.to_string_lossy().to_string());
            }
        }
    }

    // Find local servers with this team_id that are NOT in remote
    let mut stmt = conn
        .prepare("SELECT id FROM servers WHERE team_id = ?1 AND shared = 1")
        .map_err(|e| TeamSyncError::Db(e.to_string()))?;

    let local_ids: Vec<String> = stmt
        .query_map(rusqlite::params![team_id], |row| row.get(0))
        .map_err(|e| TeamSyncError::Db(e.to_string()))?
        .filter_map(|r| r.ok())
        .collect();

    let mut deleted = 0;
    for id in &local_ids {
        if !remote_ids.contains(id) {
            // Server was deleted from remote — remove locally
            conn.execute("DELETE FROM servers WHERE id = ?1", rusqlite::params![id])
                .map_err(|e| TeamSyncError::Db(e.to_string()))?;
            deleted += 1;
        }
    }

    Ok(deleted)
}

/// Imports snippets from repo into local DB using LWW merge.
pub fn import_remote_snippets(
    conn: &Connection,
    repo_path: &Path,
    team_id: &str,
) -> Result<usize, TeamSyncError> {
    let snippets_dir = repo_path.join("snippets");
    if !snippets_dir.exists() {
        return Ok(0);
    }

    let mut imported = 0;
    for entry in std::fs::read_dir(&snippets_dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.file_name().map(|n| n == "folders.json").unwrap_or(false) {
            continue;
        }
        if path.extension().map(|e| e == "json").unwrap_or(false) {
            let content = std::fs::read_to_string(&path)?;
            let remote: SharedSnippet = serde_json::from_str(&content)?;

            let local_updated = get_field_by_id(conn, "snippets", &remote.id, "updated_at");
            let decision = merge_decision(local_updated.as_deref(), &remote.updated_at);

            if decision == MergeDecision::ImportRemote {
                let tags_json = serde_json::to_string(&remote.tags).unwrap_or_default();
                conn.execute(
                    "INSERT OR REPLACE INTO snippets
                     (id, title, command, description, tags, folder_id,
                      is_favorite, usage_count, shared, team_id, shared_by, created_at, updated_at)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6,
                             COALESCE((SELECT is_favorite FROM snippets WHERE id=?1), 0),
                             COALESCE((SELECT usage_count FROM snippets WHERE id=?1), 0),
                             1, ?7, ?8,
                             COALESCE((SELECT created_at FROM snippets WHERE id=?1), ?9),
                             ?9)",
                    rusqlite::params![
                        remote.id, remote.title, remote.command, remote.description,
                        tags_json, remote.folder_id,
                        team_id, remote.shared_by, remote.updated_at,
                    ],
                )
                .map_err(|e| TeamSyncError::Db(e.to_string()))?;
                imported += 1;
            }
        }
    }

    Ok(imported)
}

/// Exports locally shared snippets to the repo.
pub fn export_local_shared_snippets(
    conn: &Connection,
    repo_path: &Path,
    username: &str,
) -> Result<usize, TeamSyncError> {
    let dir = repo_path.join("snippets");
    std::fs::create_dir_all(&dir)?;

    let mut exported = 0;
    let mut stmt = conn
        .prepare(
            "SELECT id, title, command, description, tags, folder_id,
                    shared_by, updated_at
             FROM snippets WHERE shared = 1",
        )
        .map_err(|e| TeamSyncError::Db(e.to_string()))?;

    let rows: Vec<(String, String, String, Option<String>, String, Option<String>, Option<String>, String)> = stmt
        .query_map([], |row| {
            Ok((
                row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?,
                row.get(4)?, row.get(5)?, row.get(6)?, row.get(7)?,
            ))
        })
        .map_err(|e| TeamSyncError::Db(e.to_string()))?
        .filter_map(|r| r.ok())
        .collect();

    for (id, title, command, description, tags_str, folder_id, shared_by, updated_at) in &rows {
        let file_path = dir.join(format!("{id}.json"));
        let remote_ts = read_remote_updated_at(&file_path);

        let decision = merge_decision(remote_ts.as_deref(), updated_at);
        if decision == MergeDecision::ImportRemote || remote_ts.is_none() {
            let tags: Vec<String> = serde_json::from_str(tags_str).unwrap_or_default();
            let snippet = SharedSnippet {
                id: id.clone(),
                title: title.clone(),
                command: command.clone(),
                description: description.clone(),
                tags,
                folder_id: folder_id.clone(),
                shared_by: shared_by.clone().unwrap_or_else(|| username.to_string()),
                shared_at: now_rfc3339(),
                updated_at: updated_at.clone(),
            };
            let json = serde_json::to_string_pretty(&snippet)?;
            std::fs::write(&file_path, json)?;
            exported += 1;
        }
    }

    Ok(exported)
}

/// Detects snippets deleted from remote repo.
pub fn detect_remote_deletions_snippets(
    conn: &Connection,
    repo_path: &Path,
    team_id: &str,
) -> Result<usize, TeamSyncError> {
    detect_remote_deletions_generic(conn, repo_path, "snippets", "snippets", team_id)
}

/// Syncs groups from repo (groups/groups.json) to local DB.
pub fn sync_groups(
    conn: &Connection,
    repo_path: &Path,
) -> Result<usize, TeamSyncError> {
    let path = repo_path.join("groups").join("groups.json");
    if !path.exists() {
        return Ok(0);
    }

    let content = std::fs::read_to_string(&path)?;
    let groups: SharedGroups = serde_json::from_str(&content)?;

    let mut imported = 0;
    for group in &groups.groups {
        let exists: bool = conn
            .query_row(
                "SELECT COUNT(*) FROM groups WHERE id = ?1",
                rusqlite::params![group.id],
                |row| row.get::<_, i32>(0),
            )
            .map(|c| c > 0)
            .unwrap_or(false);

        if !exists {
            conn.execute(
                "INSERT INTO groups (id, name, color, parent_id, sort_order)
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                rusqlite::params![
                    group.id, group.name, group.color, group.parent_id, group.sort_order,
                ],
            )
            .map_err(|e| TeamSyncError::Db(e.to_string()))?;
            imported += 1;
        }
    }

    Ok(imported)
}

// ── Proxy sync ──

/// Imports proxies from repo into local DB using LWW merge.
pub fn import_remote_proxies(
    conn: &Connection,
    repo_path: &Path,
    team_key: &[u8; 32],
    team_id: &str,
) -> Result<usize, TeamSyncError> {
    let dir = repo_path.join("proxies");
    if !dir.exists() {
        return Ok(0);
    }

    let mut imported = 0;
    for entry in std::fs::read_dir(&dir)? {
        let entry = entry?;
        let path = entry.path();
        if !path.extension().map(|e| e == "json").unwrap_or(false) {
            continue;
        }
        let content = std::fs::read_to_string(&path)?;
        let remote: SharedProxy = serde_json::from_str(&content)?;

        let local_updated = get_field_by_id(conn, "proxies", &remote.id, "updated_at");
        let decision = merge_decision(local_updated.as_deref(), &remote.updated_at);

        if decision == MergeDecision::ImportRemote {
            // Decrypt credentials
            let username = remote
                .username_enc
                .as_deref()
                .map(|enc| team_decrypt(team_key, enc))
                .transpose()?;
            let password = remote
                .password_enc
                .as_deref()
                .map(|enc| team_decrypt(team_key, enc))
                .transpose()?;

            // Store password in keychain
            let password_keychain_id = if let Some(ref pwd) = password {
                let kid = format!("termex:proxy:password:{}", remote.id);
                let _ = crate::keychain::store(&kid, pwd);
                Some(kid)
            } else {
                None
            };

            conn.execute(
                "INSERT OR REPLACE INTO proxies
                 (id, name, proxy_type, host, port, username, password_keychain_id,
                  tls_enabled, tls_verify, ca_cert_path, client_cert_path, client_key_path,
                  command, shared, team_id, shared_by, updated_at, created_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13,
                         1, ?14, ?15, ?16,
                         COALESCE((SELECT created_at FROM proxies WHERE id=?1), ?16))",
                rusqlite::params![
                    remote.id, remote.name, remote.proxy_type, remote.host, remote.port,
                    username, password_keychain_id,
                    remote.tls_enabled as i32, remote.tls_verify as i32,
                    remote.ca_cert_path, remote.client_cert_path, remote.client_key_path,
                    remote.command,
                    team_id, remote.shared_by, remote.updated_at,
                ],
            )
            .map_err(|e| TeamSyncError::Db(e.to_string()))?;
            imported += 1;
        }
    }

    Ok(imported)
}

/// Exports locally shared proxies to the repo.
pub fn export_local_shared_proxies(
    conn: &Connection,
    repo_path: &Path,
    team_key: &[u8; 32],
    username: &str,
) -> Result<usize, TeamSyncError> {
    let dir = repo_path.join("proxies");
    std::fs::create_dir_all(&dir)?;

    let mut exported = 0;
    let mut stmt = conn
        .prepare(
            "SELECT id, name, proxy_type, host, port, username, password_keychain_id,
                    tls_enabled, tls_verify, ca_cert_path, client_cert_path, client_key_path,
                    command, shared_by, updated_at
             FROM proxies WHERE shared = 1",
        )
        .map_err(|e| TeamSyncError::Db(e.to_string()))?;

    let rows: Vec<SharedProxyExportRow> = stmt
        .query_map([], |row| {
            Ok(SharedProxyExportRow {
                id: row.get(0)?,
                name: row.get(1)?,
                proxy_type: row.get(2)?,
                host: row.get(3)?,
                port: row.get(4)?,
                username: row.get(5)?,
                password_keychain_id: row.get(6)?,
                tls_enabled: row.get::<_, i32>(7)? != 0,
                tls_verify: row.get::<_, i32>(8)? != 0,
                ca_cert_path: row.get(9)?,
                client_cert_path: row.get(10)?,
                client_key_path: row.get(11)?,
                command: row.get(12)?,
                shared_by: row.get(13)?,
                updated_at: row.get(14)?,
            })
        })
        .map_err(|e| TeamSyncError::Db(e.to_string()))?
        .filter_map(|r| r.ok())
        .collect();

    for row in &rows {
        let file_path = dir.join(format!("{}.json", row.id));
        let remote_ts = read_remote_updated_at(&file_path);

        let decision = merge_decision(remote_ts.as_deref(), &row.updated_at);
        if decision == MergeDecision::ImportRemote || remote_ts.is_none() {
            let username_enc = row
                .username
                .as_deref()
                .filter(|u| !u.is_empty())
                .map(|u| team_encrypt(team_key, u))
                .transpose()?;

            let password_enc = row
                .password_keychain_id
                .as_deref()
                .and_then(|kid| crate::keychain::get(kid).ok())
                .map(|pwd| team_encrypt(team_key, &pwd))
                .transpose()?;

            let proxy = SharedProxy {
                id: row.id.clone(),
                name: row.name.clone(),
                proxy_type: row.proxy_type.clone(),
                host: row.host.clone(),
                port: row.port,
                username_enc,
                password_enc,
                tls_enabled: row.tls_enabled,
                tls_verify: row.tls_verify,
                ca_cert_path: row.ca_cert_path.clone(),
                client_cert_path: row.client_cert_path.clone(),
                client_key_path: row.client_key_path.clone(),
                command: row.command.clone(),
                shared_by: row.shared_by.clone().unwrap_or_else(|| username.to_string()),
                shared_at: now_rfc3339(),
                updated_at: row.updated_at.clone(),
            };

            let json = serde_json::to_string_pretty(&proxy)?;
            std::fs::write(&file_path, json)?;
            exported += 1;
        }
    }

    Ok(exported)
}

/// Detects proxies deleted from remote repo.
pub fn detect_remote_deletions_proxies(
    conn: &Connection,
    repo_path: &Path,
    team_id: &str,
) -> Result<usize, TeamSyncError> {
    detect_remote_deletions_generic(conn, repo_path, "proxies", "proxies", team_id)
}

// ── Cloud Favorites sync ──

/// Imports cloud favorites from repo into local DB using LWW merge.
pub fn import_remote_cloud_favorites(
    conn: &Connection,
    repo_path: &Path,
    team_id: &str,
) -> Result<usize, TeamSyncError> {
    let dir = repo_path.join("cloud_favorites");
    if !dir.exists() {
        return Ok(0);
    }

    let mut imported = 0;
    for entry in std::fs::read_dir(&dir)? {
        let entry = entry?;
        let path = entry.path();
        if !path.extension().map(|e| e == "json").unwrap_or(false) {
            continue;
        }
        let content = std::fs::read_to_string(&path)?;
        let remote: SharedCloudFavorite = serde_json::from_str(&content)?;

        let local_updated = get_field_by_id(conn, "cloud_favorites", &remote.id, "updated_at");
        let decision = merge_decision(local_updated.as_deref(), &remote.updated_at);

        if decision == MergeDecision::ImportRemote {
            conn.execute(
                "INSERT OR REPLACE INTO cloud_favorites
                 (id, name, resource_type, context_or_profile, namespace, region,
                  shared, team_id, shared_by, updated_at, created_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, 1, ?7, ?8, ?9,
                         COALESCE((SELECT created_at FROM cloud_favorites WHERE id=?1), ?9))",
                rusqlite::params![
                    remote.id, remote.name, remote.resource_type,
                    remote.context_or_profile, remote.namespace, remote.region,
                    team_id, remote.shared_by, remote.updated_at,
                ],
            )
            .map_err(|e| TeamSyncError::Db(e.to_string()))?;
            imported += 1;
        }
    }

    Ok(imported)
}

/// Exports locally shared cloud favorites to the repo.
pub fn export_local_shared_cloud_favorites(
    conn: &Connection,
    repo_path: &Path,
    username: &str,
) -> Result<usize, TeamSyncError> {
    let dir = repo_path.join("cloud_favorites");
    std::fs::create_dir_all(&dir)?;

    let mut exported = 0;
    let mut stmt = conn
        .prepare(
            "SELECT id, name, resource_type, context_or_profile, namespace, region,
                    shared_by, updated_at
             FROM cloud_favorites WHERE shared = 1",
        )
        .map_err(|e| TeamSyncError::Db(e.to_string()))?;

    let rows: Vec<(String, String, String, String, Option<String>, Option<String>, Option<String>, String)> = stmt
        .query_map([], |row| {
            Ok((
                row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?,
                row.get(4)?, row.get(5)?, row.get(6)?, row.get(7)?,
            ))
        })
        .map_err(|e| TeamSyncError::Db(e.to_string()))?
        .filter_map(|r| r.ok())
        .collect();

    for (id, name, resource_type, context_or_profile, namespace, region, shared_by, updated_at) in &rows {
        let file_path = dir.join(format!("{id}.json"));
        let remote_ts = read_remote_updated_at(&file_path);

        let decision = merge_decision(remote_ts.as_deref(), updated_at);
        if decision == MergeDecision::ImportRemote || remote_ts.is_none() {
            let fav = SharedCloudFavorite {
                id: id.clone(),
                name: name.clone(),
                resource_type: resource_type.clone(),
                context_or_profile: context_or_profile.clone(),
                namespace: namespace.clone(),
                region: region.clone(),
                shared_by: shared_by.clone().unwrap_or_else(|| username.to_string()),
                shared_at: now_rfc3339(),
                updated_at: updated_at.clone(),
            };
            let json = serde_json::to_string_pretty(&fav)?;
            std::fs::write(&file_path, json)?;
            exported += 1;
        }
    }

    Ok(exported)
}

/// Detects cloud favorites deleted from remote repo.
pub fn detect_remote_deletions_cloud_favorites(
    conn: &Connection,
    repo_path: &Path,
    team_id: &str,
) -> Result<usize, TeamSyncError> {
    detect_remote_deletions_generic(conn, repo_path, "cloud_favorites", "cloud_favorites", team_id)
}

// ── Recordings sync ──

/// Imports recording metadata from repo into local DB using LWW merge.
/// Only metadata is synced — actual .cast files are NOT transferred.
pub fn import_remote_recordings(
    conn: &Connection,
    repo_path: &Path,
    team_id: &str,
) -> Result<usize, TeamSyncError> {
    let dir = repo_path.join("recordings");
    if !dir.exists() {
        return Ok(0);
    }

    let mut imported = 0;
    for entry in std::fs::read_dir(&dir)? {
        let entry = entry?;
        let path = entry.path();
        if !path.extension().map(|e| e == "json").unwrap_or(false) {
            continue;
        }
        let content = std::fs::read_to_string(&path)?;
        let remote: SharedRecording = serde_json::from_str(&content)?;

        let local_updated = get_field_by_id(conn, "recordings", &remote.id, "COALESCE(ended_at, started_at)");
        // For recordings, use started_at as the timestamp for comparison
        let remote_ts = &remote.updated_at;
        let decision = merge_decision(local_updated.as_deref(), remote_ts);

        if decision == MergeDecision::ImportRemote {
            conn.execute(
                "INSERT OR REPLACE INTO recordings
                 (id, session_id, server_id, server_name, file_path,
                  file_size, duration_ms, cols, rows, event_count,
                  summary, auto_recorded, started_at, ended_at,
                  shared, team_id, shared_by, created_at)
                 VALUES (?1, '', ?2, ?3, '',
                         ?4, ?5, ?6, ?7, ?8,
                         ?9, ?10, ?11, ?12,
                         1, ?13, ?14,
                         COALESCE((SELECT created_at FROM recordings WHERE id=?1), ?11))",
                rusqlite::params![
                    remote.id, remote.server_id, remote.server_name,
                    remote.file_size, remote.duration_ms, remote.cols, remote.rows,
                    remote.event_count, remote.summary, remote.auto_recorded as i32,
                    remote.started_at, remote.ended_at,
                    team_id, remote.shared_by,
                ],
            )
            .map_err(|e| TeamSyncError::Db(e.to_string()))?;
            imported += 1;
        }
    }

    Ok(imported)
}

/// Exports locally shared recording metadata to the repo.
pub fn export_local_shared_recordings(
    conn: &Connection,
    repo_path: &Path,
    username: &str,
) -> Result<usize, TeamSyncError> {
    let dir = repo_path.join("recordings");
    std::fs::create_dir_all(&dir)?;

    let mut exported = 0;
    let mut stmt = conn
        .prepare(
            "SELECT id, server_id, server_name, file_size, duration_ms,
                    cols, rows, event_count, summary, auto_recorded,
                    started_at, ended_at, shared_by, COALESCE(ended_at, started_at) as updated_at
             FROM recordings WHERE shared = 1",
        )
        .map_err(|e| TeamSyncError::Db(e.to_string()))?;

    let rows: Vec<SharedRecordingExportRow> = stmt
        .query_map([], |row| {
            Ok(SharedRecordingExportRow {
                id: row.get(0)?,
                server_id: row.get(1)?,
                server_name: row.get(2)?,
                file_size: row.get(3)?,
                duration_ms: row.get(4)?,
                cols: row.get(5)?,
                rows: row.get(6)?,
                event_count: row.get(7)?,
                summary: row.get(8)?,
                auto_recorded: row.get::<_, i32>(9)? != 0,
                started_at: row.get(10)?,
                ended_at: row.get(11)?,
                shared_by: row.get(12)?,
                updated_at: row.get(13)?,
            })
        })
        .map_err(|e| TeamSyncError::Db(e.to_string()))?
        .filter_map(|r| r.ok())
        .collect();

    for row in &rows {
        let file_path = dir.join(format!("{}.json", row.id));
        let remote_ts = read_remote_updated_at(&file_path);

        let decision = merge_decision(remote_ts.as_deref(), &row.updated_at);
        if decision == MergeDecision::ImportRemote || remote_ts.is_none() {
            let rec = SharedRecording {
                id: row.id.clone(),
                server_id: row.server_id.clone(),
                server_name: row.server_name.clone(),
                file_size: row.file_size,
                duration_ms: row.duration_ms,
                cols: row.cols,
                rows: row.rows,
                event_count: row.event_count,
                summary: row.summary.clone(),
                auto_recorded: row.auto_recorded,
                started_at: row.started_at.clone(),
                ended_at: row.ended_at.clone(),
                shared_by: row.shared_by.clone().unwrap_or_else(|| username.to_string()),
                shared_at: now_rfc3339(),
                updated_at: row.updated_at.clone(),
            };
            let json = serde_json::to_string_pretty(&rec)?;
            std::fs::write(&file_path, json)?;
            exported += 1;
        }
    }

    Ok(exported)
}

/// Detects recordings deleted from remote repo.
pub fn detect_remote_deletions_recordings(
    conn: &Connection,
    repo_path: &Path,
    team_id: &str,
) -> Result<usize, TeamSyncError> {
    detect_remote_deletions_generic(conn, repo_path, "recordings", "recordings", team_id)
}

/// Detects conflicts between local shared servers and remote repo files.
/// A conflict occurs when both sides have changes (neither is strictly newer).
/// Returns conflicts and also the list of non-conflicting import/export decisions.
pub fn detect_server_conflicts(
    conn: &Connection,
    repo_path: &Path,
    last_sync: Option<&str>,
) -> Result<Vec<ConflictItem>, TeamSyncError> {
    let servers_dir = repo_path.join("servers");
    if !servers_dir.exists() {
        return Ok(Vec::new());
    }

    let mut conflicts = Vec::new();

    for entry in std::fs::read_dir(&servers_dir)? {
        let entry = entry?;
        let path = entry.path();
        if !path.extension().map(|e| e == "json").unwrap_or(false) {
            continue;
        }

        let content = std::fs::read_to_string(&path)?;
        let remote: SharedServerConfig = serde_json::from_str(&content)?;

        let local_updated = get_server_updated_at(conn, &remote.id);
        let local_updated_str = match &local_updated {
            Some(ts) => ts.as_str(),
            None => continue, // No local version — just import, no conflict
        };

        // Both sides have the server. Check if both changed since last sync.
        let ls = last_sync.unwrap_or("1970-01-01T00:00:00Z");
        let local_changed = local_updated_str > ls;
        let remote_changed = remote.updated_at.as_str() > ls;

        if local_changed && remote_changed && local_updated_str != remote.updated_at {
            // Both modified since last sync → conflict
            let local_name = get_server_name(conn, &remote.id).unwrap_or_default();
            let local_host = get_server_field(conn, &remote.id, "host").unwrap_or_default();
            let local_username = get_server_field(conn, &remote.id, "username").unwrap_or_default();
            let local_port = get_server_field(conn, &remote.id, "port").unwrap_or_default();

            let mut conflicting_fields = Vec::new();
            if local_name != remote.name { conflicting_fields.push("name".to_string()); }
            if local_host != remote.host { conflicting_fields.push("host".to_string()); }
            if local_username != remote.username { conflicting_fields.push("username".to_string()); }
            if local_port != remote.port.to_string() { conflicting_fields.push("port".to_string()); }

            if conflicting_fields.is_empty() {
                // Timestamps differ but fields are identical — auto-resolve by taking newer
                continue;
            }

            conflicts.push(ConflictItem {
                entity_type: "server".to_string(),
                entity_id: remote.id.clone(),
                entity_name: remote.name.clone(),
                local_value: serde_json::json!({
                    "name": local_name,
                    "host": local_host,
                    "username": local_username,
                    "port": local_port,
                }),
                remote_value: serde_json::json!({
                    "name": remote.name,
                    "host": remote.host,
                    "username": remote.username,
                    "port": remote.port,
                }),
                conflicting_fields,
                local_modified_by: "you".to_string(),
                remote_modified_by: remote.shared_by.clone(),
                local_modified_at: local_updated_str.to_string(),
                remote_modified_at: remote.updated_at.clone(),
            });
        }
    }

    Ok(conflicts)
}

/// Applies conflict resolutions.
pub fn apply_resolutions(
    conn: &Connection,
    repo_path: &Path,
    team_key: &[u8; 32],
    team_id: &str,
    resolutions: &[ConflictResolution],
) -> Result<(), TeamSyncError> {
    for res in resolutions {
        if res.entity_type != "server" { continue; }

        match res.strategy {
            ConflictStrategy::UseRemote => {
                // Import the remote version
                let file = repo_path.join("servers").join(format!("{}.json", res.entity_id));
                if file.exists() {
                    let content = std::fs::read_to_string(&file)?;
                    let remote: SharedServerConfig = serde_json::from_str(&content)?;
                    import_single_server(conn, &remote, team_key, team_id)?;
                }
                // Clear any previously skipped conflict for this entity
                let _ = conn.execute(
                    "DELETE FROM team_pending_conflicts WHERE entity_type = ?1 AND entity_id = ?2",
                    rusqlite::params![res.entity_type, res.entity_id],
                );
            }
            ConflictStrategy::KeepLocal => {
                // No action needed — local version stays, will be exported in next sync
                // Clear any previously skipped conflict for this entity
                let _ = conn.execute(
                    "DELETE FROM team_pending_conflicts WHERE entity_type = ?1 AND entity_id = ?2",
                    rusqlite::params![res.entity_type, res.entity_id],
                );
            }
            ConflictStrategy::Skip => {
                // Persist the conflict so it can be shown again later
                let file = repo_path.join("servers").join(format!("{}.json", res.entity_id));
                let remote_json = if file.exists() {
                    std::fs::read_to_string(&file).unwrap_or_default()
                } else {
                    "{}".to_string()
                };
                let local_json = get_local_server_json(conn, &res.entity_id);
                let now = time::OffsetDateTime::now_utc().to_string();
                let _ = conn.execute(
                    "INSERT OR REPLACE INTO team_pending_conflicts \
                     (entity_type, entity_id, local_value, remote_value, detected_at) \
                     VALUES (?1, ?2, ?3, ?4, ?5)",
                    rusqlite::params![res.entity_type, res.entity_id, local_json, remote_json, now],
                );
            }
        }
    }
    Ok(())
}

// ── Internal helpers ──

/// Helper row for export query.
struct SharedServerExportRow {
    id: String,
    name: String,
    host: String,
    port: u16,
    username: String,
    auth_type: String,
    password_keychain_id: Option<String>,
    passphrase_keychain_id: Option<String>,
    group_id: Option<String>,
    startup_cmd: Option<String>,
    encoding: String,
    auto_record: bool,
    shared_by: Option<String>,
    shared_at: Option<String>,
    updated_at: String,
}

fn get_server_name(conn: &Connection, server_id: &str) -> Option<String> {
    conn.query_row(
        "SELECT name FROM servers WHERE id = ?1",
        rusqlite::params![server_id],
        |row| row.get(0),
    )
    .ok()
}

fn get_server_field(conn: &Connection, server_id: &str, field: &str) -> Option<String> {
    conn.query_row(
        &format!("SELECT {field} FROM servers WHERE id = ?1"),
        rusqlite::params![server_id],
        |row| row.get::<_, rusqlite::types::Value>(0),
    )
    .ok()
    .map(|v| match v {
        rusqlite::types::Value::Text(s) => s,
        rusqlite::types::Value::Integer(n) => n.to_string(),
        _ => String::new(),
    })
}

/// Gets the `updated_at` timestamp for a local server by ID.
fn get_server_updated_at(conn: &Connection, server_id: &str) -> Option<String> {
    conn.query_row(
        "SELECT updated_at FROM servers WHERE id = ?1",
        rusqlite::params![server_id],
        |row| row.get(0),
    )
    .ok()
}

/// Gets a JSON representation of a local server for conflict persistence.
fn get_local_server_json(conn: &Connection, server_id: &str) -> String {
    let result: Option<(String, String, u16, String)> = conn
        .query_row(
            "SELECT name, host, port, username FROM servers WHERE id = ?1",
            rusqlite::params![server_id],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?)),
        )
        .ok();
    match result {
        Some((name, host, port, username)) => {
            serde_json::json!({
                "name": name,
                "host": host,
                "port": port,
                "username": username,
            })
            .to_string()
        }
        None => "{}".to_string(),
    }
}

/// Imports a single server from shared config into local DB.
fn import_single_server(
    conn: &Connection,
    remote: &SharedServerConfig,
    team_key: &[u8; 32],
    team_id: &str,
) -> Result<(), TeamSyncError> {
    // Decrypt credentials
    let password = remote
        .password_enc
        .as_deref()
        .map(|enc| team_decrypt(team_key, enc))
        .transpose()?;

    let passphrase = remote
        .passphrase_enc
        .as_deref()
        .map(|enc| team_decrypt(team_key, enc))
        .transpose()?;

    // Store in keychain
    let password_keychain_id = if let Some(ref pwd) = password {
        let kid = crate::keychain::ssh_password_key(&remote.id);
        let _ = crate::keychain::store(&kid, pwd);
        Some(kid)
    } else {
        None
    };

    let passphrase_keychain_id = if let Some(ref pp) = passphrase {
        let kid = crate::keychain::ssh_passphrase_key(&remote.id);
        let _ = crate::keychain::store(&kid, pp);
        Some(kid)
    } else {
        None
    };

    // Upsert into DB
    conn.execute(
        "INSERT OR REPLACE INTO servers
         (id, name, host, port, username, auth_type,
          password_keychain_id, passphrase_keychain_id,
          group_id, startup_cmd, encoding, auto_record,
          shared, team_id, shared_by, shared_at, updated_at, created_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12,
                 1, ?13, ?14, ?15, ?16,
                 COALESCE((SELECT created_at FROM servers WHERE id=?1), ?16))",
        rusqlite::params![
            remote.id, remote.name, remote.host, remote.port,
            remote.username, remote.auth_type,
            password_keychain_id, passphrase_keychain_id,
            remote.group_id, remote.startup_cmd, remote.encoding,
            remote.auto_record as i32,
            team_id, remote.shared_by, remote.shared_at, remote.updated_at,
        ],
    )
    .map_err(|e| TeamSyncError::Db(e.to_string()))?;

    Ok(())
}

fn now_rfc3339() -> String {
    time::OffsetDateTime::now_utc()
        .format(&time::format_description::well_known::Rfc3339)
        .unwrap_or_default()
}

/// Helper row for proxy export.
struct SharedProxyExportRow {
    id: String,
    name: String,
    proxy_type: String,
    host: String,
    port: u16,
    username: Option<String>,
    password_keychain_id: Option<String>,
    tls_enabled: bool,
    tls_verify: bool,
    ca_cert_path: Option<String>,
    client_cert_path: Option<String>,
    client_key_path: Option<String>,
    command: Option<String>,
    shared_by: Option<String>,
    updated_at: String,
}

/// Helper row for recording export.
struct SharedRecordingExportRow {
    id: String,
    server_id: String,
    server_name: String,
    file_size: i64,
    duration_ms: i64,
    cols: u32,
    rows: u32,
    event_count: i64,
    summary: Option<String>,
    auto_recorded: bool,
    started_at: String,
    ended_at: Option<String>,
    shared_by: Option<String>,
    updated_at: String,
}

/// Generic field getter for any table.
fn get_field_by_id(conn: &Connection, table: &str, id: &str, field: &str) -> Option<String> {
    conn.query_row(
        &format!("SELECT {field} FROM {table} WHERE id = ?1"),
        rusqlite::params![id],
        |row| row.get::<_, rusqlite::types::Value>(0),
    )
    .ok()
    .and_then(|v| match v {
        rusqlite::types::Value::Text(s) => Some(s),
        rusqlite::types::Value::Integer(n) => Some(n.to_string()),
        rusqlite::types::Value::Null => None,
        _ => None,
    })
}

/// Generic remote deletion detection — works for any table with id/team_id/shared columns.
fn detect_remote_deletions_generic(
    conn: &Connection,
    repo_path: &Path,
    repo_dir: &str,
    table: &str,
    team_id: &str,
) -> Result<usize, TeamSyncError> {
    let dir = repo_path.join(repo_dir);

    let mut remote_ids = HashSet::new();
    if dir.exists() {
        for entry in std::fs::read_dir(&dir)? {
            let entry = entry?;
            let path = entry.path();
            if let Some(stem) = path.file_stem() {
                let name = stem.to_string_lossy().to_string();
                if name != ".gitkeep" {
                    remote_ids.insert(name);
                }
            }
        }
    }

    let query = format!("SELECT id FROM {table} WHERE team_id = ?1 AND shared = 1");
    let mut stmt = conn
        .prepare(&query)
        .map_err(|e| TeamSyncError::Db(e.to_string()))?;

    let local_ids: Vec<String> = stmt
        .query_map(rusqlite::params![team_id], |row| row.get(0))
        .map_err(|e| TeamSyncError::Db(e.to_string()))?
        .filter_map(|r| r.ok())
        .collect();

    let mut deleted = 0;
    for id in &local_ids {
        if !remote_ids.contains(id) {
            let del = format!("DELETE FROM {table} WHERE id = ?1");
            conn.execute(&del, rusqlite::params![id])
                .map_err(|e| TeamSyncError::Db(e.to_string()))?;
            deleted += 1;
        }
    }

    Ok(deleted)
}

/// Reads the `updated_at` field from a JSON file, returning None if missing or unreadable.
fn read_remote_updated_at(file_path: &Path) -> Option<String> {
    if !file_path.exists() {
        return None;
    }
    let content = std::fs::read_to_string(file_path).ok()?;
    let val: serde_json::Value = serde_json::from_str(&content).ok()?;
    val.get("updated_at")
        .or_else(|| val.get("updatedAt"))
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
}
