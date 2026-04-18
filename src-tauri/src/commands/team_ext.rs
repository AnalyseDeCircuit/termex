//! Extended team commands: credentials, permissions, roles, invite tokens.
//!
//! Split from commands/team.rs to stay within the 800-line limit.

use base64::Engine;
use tauri::State;

use crate::state::AppState;
use crate::team::git::TeamRepo;
use crate::team::permission;
use crate::team::sync;
use crate::team::types::*;

use super::team::{check_capability, get_team_username, load_git_auth};

// ── Credentials ─────────────────────────────────────────────

/// Gets shared server credentials (permission-controlled).
#[tauri::command]
pub async fn team_get_credentials(
    state: State<'_, AppState>,
    server_id: String,
    purpose: String,
) -> Result<Option<serde_json::Value>, String> {
    let group_id: Option<String> = state.db.with_conn(|conn| {
        conn.query_row(
            "SELECT group_id FROM servers WHERE id = ?1",
            rusqlite::params![server_id],
            |row| row.get(0),
        )
    }).ok().flatten();

    match purpose.as_str() {
        "connect" => {
            check_capability(&state, &Capability::ServerConnect, group_id.as_deref()).await?;
        }
        "view" => {
            check_capability(&state, &Capability::ServerViewCredentials, group_id.as_deref()).await?;
            let server_name: String = state.db.with_conn(|conn| {
                conn.query_row(
                    "SELECT name FROM servers WHERE id = ?1",
                    rusqlite::params![server_id],
                    |row| row.get(0),
                )
            }).unwrap_or_else(|_| "unknown".to_string());
            crate::audit::log(&state.db, crate::audit::AuditEvent::TeamCredentialAccess {
                server_id: server_id.clone(),
                server_name,
            });
        }
        _ => return Err("invalid purpose: use 'connect' or 'view'".to_string()),
    }

    let creds = state.db.with_conn(|conn| {
        conn.query_row(
            "SELECT password_keychain_id, passphrase_keychain_id FROM servers WHERE id = ?1",
            rusqlite::params![server_id],
            |row| Ok((row.get::<_, Option<String>>(0)?, row.get::<_, Option<String>>(1)?)),
        )
    }).map_err(|e| e.to_string())?;

    let password = creds.0.as_deref().and_then(|kid| crate::keychain::get(kid).ok());
    let passphrase = creds.1.as_deref().and_then(|kid| crate::keychain::get(kid).ok());

    Ok(Some(serde_json::json!({ "password": password, "passphrase": passphrase })))
}

// ── Permission queries ──────────────────────────────────────

/// Checks if the current user has a given capability.
#[tauri::command]
pub async fn team_check_permission(
    state: State<'_, AppState>,
    capability: Capability,
    group_id: Option<String>,
) -> Result<bool, String> {
    let username = get_team_username(&state)?;
    let repo_path = state.team_repo_path.read().await.clone()
        .ok_or("not in a team")?;
    let team = sync::read_team_json(&repo_path).map_err(|e| e.to_string())?;
    Ok(permission::check_permission(&team, &username, &capability, group_id.as_deref()))
}

/// Returns all role definitions (preset + custom).
#[tauri::command]
pub async fn team_list_roles(
    state: State<'_, AppState>,
) -> Result<std::collections::HashMap<String, TeamRole>, String> {
    let repo_path = state.team_repo_path.read().await.clone()
        .ok_or("not in a team")?;
    let team = sync::read_team_json(&repo_path).map_err(|e| e.to_string())?;
    Ok(team.roles)
}

/// Returns the current user's capabilities.
#[tauri::command]
pub async fn team_my_capabilities(
    state: State<'_, AppState>,
) -> Result<Vec<Capability>, String> {
    let username = get_team_username(&state)?;
    let repo_path = state.team_repo_path.read().await.clone()
        .ok_or("not in a team")?;
    let team = sync::read_team_json(&repo_path).map_err(|e| e.to_string())?;
    let member = team.members.iter()
        .find(|m| m.username == username)
        .ok_or("member not found")?;
    let role = team.roles.get(&member.role).ok_or("role not found")?;
    Ok(role.capabilities.clone())
}

// ── Role CRUD ───────────────────────────────────────────────

/// Creates a custom role.
#[tauri::command]
pub async fn team_role_create(
    state: State<'_, AppState>,
    name: String,
    display_name: String,
    capabilities: Vec<Capability>,
) -> Result<(), String> {
    check_capability(&state, &Capability::TeamSettingsEdit, None).await?;
    let repo_path = state.team_repo_path.read().await.clone().ok_or("not in a team")?;
    let mut team = sync::read_team_json(&repo_path).map_err(|e| e.to_string())?;
    if team.roles.contains_key(&name) {
        return Err(format!("role '{}' already exists", name));
    }
    team.roles.insert(name, TeamRole { display_name, capabilities });
    sync::write_team_json(&repo_path, &team).map_err(|e| e.to_string())?;
    let auth = load_git_auth(&state)?;
    let username = get_team_username(&state)?;
    let repo = TeamRepo::open(&repo_path).map_err(|e| e.to_string())?;
    repo.commit_and_push("add custom role", &username, &auth).map_err(|e| e.to_string())?;
    Ok(())
}

/// Updates a custom role. Preset roles cannot be modified.
#[tauri::command]
pub async fn team_role_update(
    state: State<'_, AppState>,
    name: String,
    display_name: String,
    capabilities: Vec<Capability>,
) -> Result<(), String> {
    check_capability(&state, &Capability::TeamSettingsEdit, None).await?;
    if ["admin", "ops", "developer", "viewer"].contains(&name.as_str()) {
        return Err("preset roles cannot be modified".to_string());
    }
    let repo_path = state.team_repo_path.read().await.clone().ok_or("not in a team")?;
    let mut team = sync::read_team_json(&repo_path).map_err(|e| e.to_string())?;
    let role = team.roles.get_mut(&name).ok_or("role not found")?;
    role.display_name = display_name;
    role.capabilities = capabilities;
    sync::write_team_json(&repo_path, &team).map_err(|e| e.to_string())?;
    let auth = load_git_auth(&state)?;
    let username = get_team_username(&state)?;
    let repo = TeamRepo::open(&repo_path).map_err(|e| e.to_string())?;
    repo.commit_and_push(&format!("update role: {name}"), &username, &auth).map_err(|e| e.to_string())?;
    Ok(())
}

/// Deletes a custom role. Fails if any member uses it.
#[tauri::command]
pub async fn team_role_delete(
    state: State<'_, AppState>,
    name: String,
) -> Result<(), String> {
    check_capability(&state, &Capability::TeamSettingsEdit, None).await?;
    if ["admin", "ops", "developer", "viewer"].contains(&name.as_str()) {
        return Err("preset roles cannot be deleted".to_string());
    }
    let repo_path = state.team_repo_path.read().await.clone().ok_or("not in a team")?;
    let mut team = sync::read_team_json(&repo_path).map_err(|e| e.to_string())?;
    if team.members.iter().any(|m| m.role == name) {
        return Err("cannot delete a role that is in use".to_string());
    }
    team.roles.remove(&name);
    sync::write_team_json(&repo_path, &team).map_err(|e| e.to_string())?;
    let auth = load_git_auth(&state)?;
    let username = get_team_username(&state)?;
    let repo = TeamRepo::open(&repo_path).map_err(|e| e.to_string())?;
    repo.commit_and_push(&format!("delete role: {name}"), &username, &auth).map_err(|e| e.to_string())?;
    Ok(())
}

// ── Invite Token ────────────────────────────────────────────

#[derive(Debug, serde::Serialize, serde::Deserialize)]
struct InvitePayload {
    team_name: String,
    repo_url: String,
    invited_by: String,
    role: String,
    expires_at: String,
}

/// Generates an invite token (base64-encoded JSON).
#[tauri::command]
pub async fn team_generate_invite_token(
    state: State<'_, AppState>,
    role: String,
    expires_days: u32,
) -> Result<String, String> {
    check_capability(&state, &Capability::TeamInvite, None).await?;
    let username = get_team_username(&state)?;
    let repo_url = state.db.with_conn(|conn| {
        conn.query_row("SELECT value FROM settings WHERE key='team_repo_url'", [], |r| r.get::<_, String>(0))
    }).map_err(|_| "repo url not found")?;
    let team_name = state.db.with_conn(|conn| {
        conn.query_row("SELECT value FROM settings WHERE key='team_name'", [], |r| r.get::<_, String>(0))
    }).map_err(|_| "team name not found")?;
    let expires_at = {
        let now = time::OffsetDateTime::now_utc();
        let dur = time::Duration::days(expires_days.max(1).min(30) as i64);
        (now + dur).format(&time::format_description::well_known::Rfc3339).unwrap_or_default()
    };
    let payload = InvitePayload { team_name, repo_url, invited_by: username, role, expires_at };
    let json = serde_json::to_string(&payload).map_err(|e| e.to_string())?;
    Ok(base64::engine::general_purpose::STANDARD.encode(json.as_bytes()))
}

/// Decodes and validates an invite token.
#[tauri::command]
pub async fn team_decode_invite(token: String) -> Result<serde_json::Value, String> {
    let decoded = base64::engine::general_purpose::STANDARD.decode(&token)
        .map_err(|_| "invalid invite token format")?;
    let json_str = String::from_utf8(decoded).map_err(|_| "invalid invite token encoding")?;
    let payload: InvitePayload = serde_json::from_str(&json_str)
        .map_err(|_| "invalid invite token data")?;
    let now = time::OffsetDateTime::now_utc()
        .format(&time::format_description::well_known::Rfc3339).unwrap_or_default();
    if now > payload.expires_at {
        return Err("invite token has expired".to_string());
    }
    Ok(serde_json::json!({
        "teamName": payload.team_name, "repoUrl": payload.repo_url,
        "invitedBy": payload.invited_by, "role": payload.role, "expiresAt": payload.expires_at,
    }))
}
