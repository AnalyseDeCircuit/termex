use tauri::{AppHandle, Emitter, State};

use crate::crypto::aes;
use crate::keychain;
use crate::ssh::session::SshSession;
use crate::ssh::{auth, SshError};
use crate::state::AppState;
use crate::storage::models::AuthType;

/// Connects to an SSH server and opens a shell session.
/// Returns the session_id for subsequent operations.
#[tauri::command]
pub async fn ssh_connect(
    state: State<'_, AppState>,
    app: AppHandle,
    server_id: String,
    cols: u32,
    rows: u32,
) -> Result<String, String> {
    let session_id = uuid::Uuid::new_v4().to_string();
    let status_event = format!("ssh://status/{session_id}");

    // Load server details from database
    let server = state
        .db
        .with_conn(|conn| {
            conn.query_row(
                "SELECT host, port, username, auth_type, password_enc, key_path, passphrase_enc
                 FROM servers WHERE id = ?1",
                rusqlite::params![server_id],
                |row| {
                    Ok(ServerInfo {
                        host: row.get(0)?,
                        port: row.get(1)?,
                        username: row.get(2)?,
                        auth_type: row.get(3)?,
                        password_enc: row.get(4)?,
                        key_path: row.get(5)?,
                        passphrase_enc: row.get(6)?,
                        server_id: server_id.clone(),
                    })
                },
            )
        })
        .map_err(|e| e.to_string())?;

    // Emit connecting status
    let _ = app.emit(
        &status_event,
        serde_json::json!({"status": "connecting", "message": "connecting..."}),
    );

    // Connect to SSH server (10s timeout)
    let mut ssh_session = tokio::time::timeout(
        std::time::Duration::from_secs(10),
        SshSession::connect(&server.host, server.port as u16),
    )
    .await
    .map_err(|_| {
        let err = SshError::ConnectionFailed("connection timed out (10s)".into());
        emit_error(&app, &status_event, &err)
    })?
    .map_err(|e| emit_error(&app, &status_event, &e))?;

    // Authenticate
    let auth_type = AuthType::from_str(&server.auth_type).unwrap_or(AuthType::Password);
    match auth_type {
        AuthType::Password => {
            // Try keychain first, then legacy encrypted field
            let password = keychain::get(&keychain::ssh_password_key(&server.server_id))
                .unwrap_or_else(|_| decrypt_field(&state, server.password_enc).unwrap_or_default());
            auth::auth_password(ssh_session.handle_mut(), &server.username, &password)
                .await
                .map_err(|e| emit_error(&app, &status_event, &e))?;
        }
        AuthType::Key => {
            let key_path = server
                .key_path
                .as_deref()
                .ok_or("no key path configured")?;
            // Try keychain first for passphrase
            let passphrase = keychain::get(&keychain::ssh_passphrase_key(&server.server_id))
                .ok()
                .or_else(|| {
                    server.passphrase_enc.and_then(|enc| {
                        decrypt_field(&state, Some(enc)).ok().filter(|s| !s.is_empty())
                    })
                });
            auth::auth_key(
                ssh_session.handle_mut(),
                &server.username,
                key_path,
                passphrase.as_deref(),
            )
            .await
            .map_err(|e| emit_error(&app, &status_event, &e))?;
        }
    }

    // Open shell channel
    ssh_session
        .open_shell(app.clone(), session_id.clone(), cols, rows)
        .await
        .map_err(|e| emit_error(&app, &status_event, &e))?;

    // Store session
    {
        let mut sessions = state.sessions.write().await;
        sessions.insert(session_id.clone(), ssh_session);
    }

    // Emit connected status
    let _ = app.emit(
        &status_event,
        serde_json::json!({
            "status": "connected",
            "message": format!("{}@{}:{}", server.username, server.host, server.port),
        }),
    );

    // Update last_connected
    let now = chrono::Utc::now().to_rfc3339();
    let _ = state.db.with_conn(|conn| {
        conn.execute(
            "UPDATE servers SET last_connected = ?1, updated_at = ?1 WHERE id = ?2",
            rusqlite::params![now, server_id],
        )
    });

    Ok(session_id)
}

/// Tests SSH connectivity using form input (without saving).
#[tauri::command]
pub async fn ssh_test(
    state: State<'_, AppState>,
    host: String,
    port: u32,
    username: String,
    auth_type: String,
    password: Option<String>,
    key_path: Option<String>,
    passphrase: Option<String>,
) -> Result<String, String> {
    // Connect (10s timeout)
    let mut ssh_session = tokio::time::timeout(
        std::time::Duration::from_secs(10),
        SshSession::connect(&host, port as u16),
    )
    .await
    .map_err(|_| "connection timed out (10s)".to_string())?
    .map_err(|e| e.to_string())?;

    // Authenticate
    let at = AuthType::from_str(&auth_type).unwrap_or(AuthType::Password);
    match at {
        AuthType::Password => {
            let pw = password.unwrap_or_default();
            auth::auth_password(ssh_session.handle_mut(), &username, &pw)
                .await
                .map_err(|e| e.to_string())?;
        }
        AuthType::Key => {
            let kp = key_path.as_deref().ok_or("no key path")?;
            auth::auth_key(ssh_session.handle_mut(), &username, kp, passphrase.as_deref())
                .await
                .map_err(|e| e.to_string())?;
        }
    }

    // Disconnect immediately
    let _ = ssh_session.disconnect().await;

    Ok("ok".into())
}

/// Disconnects an SSH session.
#[tauri::command]
pub async fn ssh_disconnect(
    state: State<'_, AppState>,
    session_id: String,
) -> Result<(), String> {
    // Also close SFTP session if open
    {
        let mut sftp_sessions = state.sftp_sessions.write().await;
        if let Some(sftp) = sftp_sessions.remove(&session_id) {
            let _ = sftp.close().await;
        }
    }

    let session = {
        let mut sessions = state.sessions.write().await;
        sessions
            .remove(&session_id)
            .ok_or_else(|| SshError::SessionNotFound(session_id.clone()).to_string())?
    };
    session.disconnect().await.map_err(|e| e.to_string())
}

/// Writes user input data to the SSH shell channel. Non-blocking.
#[tauri::command]
pub async fn ssh_write(
    state: State<'_, AppState>,
    session_id: String,
    data: Vec<u8>,
) -> Result<(), String> {
    let sessions = state.sessions.read().await;
    let session = sessions
        .get(&session_id)
        .ok_or_else(|| SshError::SessionNotFound(session_id).to_string())?;
    session.write(&data).map_err(|e| e.to_string())
}

/// Resizes the terminal window for an SSH session. Non-blocking.
#[tauri::command]
pub async fn ssh_resize(
    state: State<'_, AppState>,
    session_id: String,
    cols: u32,
    rows: u32,
) -> Result<(), String> {
    let sessions = state.sessions.read().await;
    let session = sessions
        .get(&session_id)
        .ok_or_else(|| SshError::SessionNotFound(session_id).to_string())?;
    session.resize(cols, rows).map_err(|e| e.to_string())
}

// ── Internal ───────────────────────────────────────────────────

struct ServerInfo {
    server_id: String,
    host: String,
    port: i32,
    username: String,
    auth_type: String,
    password_enc: Option<Vec<u8>>,
    key_path: Option<String>,
    passphrase_enc: Option<Vec<u8>>,
}

/// Emits an error status event and returns the error string.
fn emit_error(app: &AppHandle, event: &str, err: &SshError) -> String {
    let _ = app.emit(
        event,
        serde_json::json!({"status": "error", "message": err.to_string()}),
    );
    err.to_string()
}

/// Decrypts an encrypted field using the master key.
fn decrypt_field(
    state: &State<'_, AppState>,
    encrypted: Option<Vec<u8>>,
) -> Result<String, String> {
    let Some(data) = encrypted else {
        return Ok(String::new());
    };

    let mk = state.master_key.read().expect("master_key lock poisoned");
    if let Some(ref key) = *mk {
        let plaintext = aes::decrypt(key, &data).map_err(|e| e.to_string())?;
        String::from_utf8(plaintext).map_err(|e| e.to_string())
    } else {
        String::from_utf8(data).map_err(|e| e.to_string())
    }
}
