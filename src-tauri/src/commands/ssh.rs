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

    // Load server details from database (including proxy_id for bastion support)
    let server = state
        .db
        .with_conn(|conn| {
            conn.query_row(
                "SELECT host, port, username, auth_type, password_enc, key_path, passphrase_enc, proxy_id
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
                        proxy_id: row.get(7)?,
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

    // Handle ProxyJump (bastion host support)
    let mut ssh_session;
    let mut proxy_chain = Vec::new();

    if let Some(bastion_id) = &server.proxy_id {
        // Connect via bastion: load bastion server details
        let _ = app.emit(
            &status_event,
            serde_json::json!({"status": "connecting", "message": "connecting to bastion..."}),
        );

        let bastion_info = state
            .db
            .with_conn(|conn| {
                conn.query_row(
                    "SELECT host, port, username, auth_type, password_enc, key_path, passphrase_enc
                     FROM servers WHERE id = ?1",
                    rusqlite::params![bastion_id],
                    |row| {
                        Ok(ServerInfo {
                            host: row.get(0)?,
                            port: row.get(1)?,
                            username: row.get(2)?,
                            auth_type: row.get(3)?,
                            password_enc: row.get(4)?,
                            key_path: row.get(5)?,
                            passphrase_enc: row.get(6)?,
                            proxy_id: None,
                            server_id: bastion_id.clone(),
                        })
                    },
                )
            })
            .map_err(|e| {
                let err = SshError::ServerNotFound(format!("Failed to load bastion server: {}", e));
                emit_error(&app, &status_event, &err)
            })?;

        // Connect to bastion (check if already in pool)
        {
            let mut proxy_sessions = state.proxy_sessions.write().await;
            if proxy_sessions.contains_key(bastion_id) {
                // Bastion already connected, reuse and increment ref_count
                if let Some(entry) = proxy_sessions.get_mut(bastion_id) {
                    entry.ref_count += 1;
                    eprintln!(">>> [PROXY] Reusing bastion connection: {} (ref_count: {})", bastion_id, entry.ref_count);
                }
            } else {
                // First time: connect to bastion
                let mut bastion_session = tokio::time::timeout(
                    std::time::Duration::from_secs(10),
                    SshSession::connect(&bastion_info.host, bastion_info.port as u16),
                )
                .await
                .map_err(|_| {
                    let err = SshError::ConnectionFailed("bastion connection timed out (10s)".into());
                    emit_error(&app, &status_event, &err)
                })?
                .map_err(|e| emit_error(&app, &status_event, &e))?;

                // Authenticate bastion
                let bastion_auth_type = AuthType::from_str(&bastion_info.auth_type)
                    .unwrap_or(AuthType::Password);
                match bastion_auth_type {
                    AuthType::Password => {
                        let password = keychain::get(&keychain::ssh_password_key(&bastion_info.server_id))
                            .unwrap_or_else(|_| decrypt_field(&state, bastion_info.password_enc).unwrap_or_default());
                        auth::auth_password(bastion_session.handle_mut(), &bastion_info.username, &password)
                            .await
                            .map_err(|e| emit_error(&app, &status_event, &SshError::AuthFailed(format!("Bastion auth failed: {}", e))))?;
                    }
                    AuthType::Key => {
                        let key_path = bastion_info
                            .key_path
                            .as_deref()
                            .ok_or_else(|| emit_error(&app, &status_event, &SshError::AuthFailed("bastion: no key path configured".into())))?;
                        let passphrase = keychain::get(&keychain::ssh_passphrase_key(&bastion_info.server_id))
                            .ok()
                            .or_else(|| {
                                bastion_info.passphrase_enc.and_then(|enc| {
                                    decrypt_field(&state, Some(enc)).ok().filter(|s| !s.is_empty())
                                })
                            });
                        auth::auth_key(
                            bastion_session.handle_mut(),
                            &bastion_info.username,
                            key_path,
                            passphrase.as_deref(),
                        )
                        .await
                        .map_err(|e| emit_error(&app, &status_event, &SshError::AuthFailed(format!("Bastion auth failed: {}", e))))?;
                    }
                }

                proxy_sessions.insert(bastion_id.clone(), crate::state::ProxyEntry {
                    session: Box::new(bastion_session),
                    ref_count: 1,
                });
                eprintln!(">>> [PROXY] New bastion connection established: {}", bastion_id);
            }
        }

        // Connect to target via bastion (direct-tcpip)
        let _ = app.emit(
            &status_event,
            serde_json::json!({"status": "connecting", "message": "connecting via bastion to target..."}),
        );

        // Get bastion handle for direct-tcpip (need to temporarily borrow it)
        let proxy_sessions = state.proxy_sessions.read().await;
        let bastion_entry = proxy_sessions.get(bastion_id)
            .ok_or_else(|| {
                let err = SshError::ConnectionFailed("bastion session not found in pool".into());
                emit_error(&app, &status_event, &err)
            })?;
        let bastion_handle = bastion_entry.session.handle();

        ssh_session = tokio::time::timeout(
            std::time::Duration::from_secs(10),
            SshSession::connect_via_proxy(&bastion_handle, &server.host, server.port as u16),
        )
        .await
        .map_err(|_| {
            let err = SshError::ConnectionFailed("target connection timed out (10s)".into());
            emit_error(&app, &status_event, &err)
        })?
        .map_err(|e| emit_error(&app, &status_event, &e))?;

        drop(proxy_sessions); // Release the read lock
        proxy_chain.push(bastion_id.clone());
    } else {
        // Direct connection (no bastion)
        ssh_session = tokio::time::timeout(
            std::time::Duration::from_secs(10),
            SshSession::connect(&server.host, server.port as u16),
        )
        .await
        .map_err(|_| {
            let err = SshError::ConnectionFailed("connection timed out (10s)".into());
            emit_error(&app, &status_event, &err)
        })?
        .map_err(|e| emit_error(&app, &status_event, &e))?;
    }

    // Authenticate target server
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

    // Store proxy_chain in session for later cleanup
    ssh_session.proxy_chain = proxy_chain;

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
    let now = time::OffsetDateTime::now_utc().to_string();
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
    _state: State<'_, AppState>,
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

/// Disconnects an SSH session and cleans up proxy session references.
#[tauri::command]
pub async fn ssh_disconnect(
    state: State<'_, AppState>,
    session_id: String,
) -> Result<(), String> {
    // Also close SFTP session if open
    {
        let mut sftp_sessions = state.sftp_sessions.write().await;
        if let Some(sftp) = sftp_sessions.remove(&session_id) {
            // Try to unwrap the Arc; if there are pending transfers, just drop it
            if let Ok(sftp_handle) = std::sync::Arc::try_unwrap(sftp) {
                let _ = sftp_handle.close().await;
            }
        }
    }

    let session = {
        let mut sessions = state.sessions.write().await;
        sessions
            .remove(&session_id)
            .ok_or_else(|| SshError::SessionNotFound(session_id.clone()).to_string())?
    };

    // Disconnect and get proxy_chain for reference count cleanup
    let proxy_chain = session.disconnect().await.map_err(|e| e.to_string())?;

    // Decrement reference counts for all proxy sessions in the chain
    if !proxy_chain.is_empty() {
        let mut proxy_sessions = state.proxy_sessions.write().await;
        for bastion_id in proxy_chain {
            if let Some(entry) = proxy_sessions.get_mut(&bastion_id) {
                entry.ref_count = entry.ref_count.saturating_sub(1);
                eprintln!(">>> [PROXY] Decremented ref_count for {}: {}", bastion_id, entry.ref_count);

                // Close bastion connection if ref_count reaches 0
                if entry.ref_count == 0 {
                    proxy_sessions.remove(&bastion_id);
                    eprintln!(">>> [PROXY] Removed bastion connection: {} (ref_count = 0)", bastion_id);
                }
            }
        }
    }

    Ok(())
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

#[derive(Clone)]
struct ServerInfo {
    server_id: String,
    host: String,
    port: i32,
    username: String,
    auth_type: String,
    password_enc: Option<Vec<u8>>,
    key_path: Option<String>,
    passphrase_enc: Option<Vec<u8>>,
    proxy_id: Option<String>,
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

/// Resolves a server's proxy chain by recursively querying proxy_id.
/// Returns the chain in connection order: [outermost_bastion, ..., intermediate_hop, target]
/// This allows us to connect outermost first, then tunnel through each hop to reach target.
///
/// Detects circular proxy configurations and returns an error if found.
fn resolve_proxy_chain(
    state: &State<'_, AppState>,
    server_id: &str,
) -> Result<Vec<ServerInfo>, String> {
    let mut chain = Vec::new();
    let mut visited = std::collections::HashSet::new();
    let mut current_id = server_id.to_string();

    // Recursively follow proxy_id chain backwards
    loop {
        if visited.contains(&current_id) {
            return Err(format!("Circular proxy configuration detected at server: {}", current_id));
        }
        visited.insert(current_id.clone());

        let server_info = state
            .db
            .with_conn(|conn| {
                conn.query_row(
                    "SELECT id, host, port, username, auth_type, password_enc, key_path, passphrase_enc, proxy_id
                     FROM servers WHERE id = ?1",
                    rusqlite::params![current_id],
                    |row| {
                        Ok(ServerInfo {
                            server_id: row.get(0)?,
                            host: row.get(1)?,
                            port: row.get(2)?,
                            username: row.get(3)?,
                            auth_type: row.get(4)?,
                            password_enc: row.get(5)?,
                            key_path: row.get(6)?,
                            passphrase_enc: row.get(7)?,
                            proxy_id: row.get(8)?,
                        })
                    },
                )
            })
            .map_err(|_| format!("Server not found: {}", current_id))?;

        chain.push(server_info.clone());

        // Move to proxy if it exists, otherwise we're done
        if let Some(proxy_id) = &server_info.proxy_id {
            current_id = proxy_id.clone();
        } else {
            break;
        }
    }

    // Reverse the chain so it goes from outermost_bastion → ... → intermediate → target
    // (we need outermost_bastion first to connect through chain)
    chain.reverse();

    Ok(chain)
}

/// Connects to a target server through a chain of bastion hosts.
/// For now, supports single bastion (Phase 2 will extend to multi-hop).
/// chain: [target] or [bastion, target]
async fn connect_via_chain(
    state: &State<'_, AppState>,
    app: &AppHandle,
    status_event: &str,
    chain: Vec<ServerInfo>,
) -> Result<(SshSession, Vec<String>), String> {
    if chain.is_empty() {
        return Err("Empty proxy chain".into());
    }

    let mut proxy_chain = Vec::new();
    let target = chain.last().unwrap();

    // Handle direct connection or via bastion(s)
    let mut ssh_session = if chain.len() == 1 {
        // Direct connection
        let _ = app.emit(
            status_event,
            serde_json::json!({"status": "connecting", "message": "connecting..."}),
        );
        tokio::time::timeout(
            std::time::Duration::from_secs(10),
            SshSession::connect(&target.host, target.port as u16),
        )
        .await
        .map_err(|_| {
            let err = SshError::ConnectionFailed("connection timed out (10s)".into());
            emit_error(&app, &status_event, &err)
        })?
        .map_err(|e| emit_error(&app, &status_event, &e))?
    } else {
        // Via bastion(s) - for now, only support one bastion (chain[0])
        let bastion = &chain[0];
        let _ = app.emit(
            status_event,
            serde_json::json!({"status": "connecting", "message": format!("connecting to bastion {}...", bastion.host)}),
        );

        // Check if bastion already in pool
        {
            let mut proxy_sessions = state.proxy_sessions.write().await;
            if proxy_sessions.contains_key(&bastion.server_id) {
                if let Some(entry) = proxy_sessions.get_mut(&bastion.server_id) {
                    entry.ref_count += 1;
                    eprintln!(">>> [PROXY] Reusing bastion connection: {} (ref_count: {})", bastion.server_id, entry.ref_count);
                }
                proxy_chain.push(bastion.server_id.clone());
            } else {
                // Connect to new bastion
                let mut bastion_session = tokio::time::timeout(
                    std::time::Duration::from_secs(10),
                    SshSession::connect(&bastion.host, bastion.port as u16),
                )
                .await
                .map_err(|_| {
                    let err = SshError::ConnectionFailed("bastion connection timed out (10s)".into());
                    emit_error(&app, &status_event, &err)
                })?
                .map_err(|e| emit_error(&app, &status_event, &e))?;

                // Authenticate bastion
                let bastion_auth_type = AuthType::from_str(&bastion.auth_type).unwrap_or(AuthType::Password);
                match bastion_auth_type {
                    AuthType::Password => {
                        let password = keychain::get(&keychain::ssh_password_key(&bastion.server_id))
                            .unwrap_or_else(|_| decrypt_field(&state, bastion.password_enc.clone()).unwrap_or_default());
                        auth::auth_password(bastion_session.handle_mut(), &bastion.username, &password)
                            .await
                            .map_err(|e| emit_error(&app, &status_event, &SshError::AuthFailed(format!("Bastion auth failed: {}", e))))?;
                    }
                    AuthType::Key => {
                        let key_path = bastion.key_path.as_deref()
                            .ok_or_else(|| emit_error(&app, &status_event, &SshError::AuthFailed("bastion: no key path configured".into())))?;
                        let passphrase = keychain::get(&keychain::ssh_passphrase_key(&bastion.server_id))
                            .ok()
                            .or_else(|| {
                                bastion.passphrase_enc.clone().and_then(|enc| {
                                    decrypt_field(&state, Some(enc)).ok().filter(|s| !s.is_empty())
                                })
                            });
                        auth::auth_key(bastion_session.handle_mut(), &bastion.username, key_path, passphrase.as_deref())
                            .await
                            .map_err(|e| emit_error(&app, &status_event, &SshError::AuthFailed(format!("Bastion auth failed: {}", e))))?;
                    }
                }

                proxy_sessions.insert(bastion.server_id.clone(), crate::state::ProxyEntry {
                    session: Box::new(bastion_session),
                    ref_count: 1,
                });
                proxy_chain.push(bastion.server_id.clone());
            }
        }

        // Connect to target via bastion
        let _ = app.emit(
            status_event,
            serde_json::json!({"status": "connecting", "message": format!("connecting via bastion to target {}...", target.host)}),
        );

        let proxy_sessions = state.proxy_sessions.read().await;
        let bastion_entry = proxy_sessions.get(&bastion.server_id)
            .ok_or_else(|| {
                let err = SshError::ConnectionFailed("bastion session not found in pool".into());
                emit_error(&app, &status_event, &err)
            })?;
        let bastion_handle = bastion_entry.session.handle();

        let target_session = tokio::time::timeout(
            std::time::Duration::from_secs(10),
            SshSession::connect_via_proxy(&bastion_handle, &target.host, target.port as u16),
        )
        .await
        .map_err(|_| {
            let err = SshError::ConnectionFailed("target connection timed out (10s)".into());
            emit_error(&app, &status_event, &err)
        })?
        .map_err(|e| emit_error(&app, &status_event, &e))?;

        drop(proxy_sessions);
        target_session
    };

    // Authenticate target
    let auth_type = AuthType::from_str(&target.auth_type).unwrap_or(AuthType::Password);
    match auth_type {
        AuthType::Password => {
            let password = keychain::get(&keychain::ssh_password_key(&target.server_id))
                .unwrap_or_else(|_| decrypt_field(&state, target.password_enc.clone()).unwrap_or_default());
            auth::auth_password(ssh_session.handle_mut(), &target.username, &password)
                .await
                .map_err(|e| emit_error(&app, &status_event, &e))?;
        }
        AuthType::Key => {
            let key_path = target.key_path.as_deref()
                .ok_or("no key path configured")?;
            let passphrase = keychain::get(&keychain::ssh_passphrase_key(&target.server_id))
                .ok()
                .or_else(|| {
                    target.passphrase_enc.clone().and_then(|enc| {
                        decrypt_field(&state, Some(enc)).ok().filter(|s| !s.is_empty())
                    })
                });
            auth::auth_key(ssh_session.handle_mut(), &target.username, key_path, passphrase.as_deref())
                .await
                .map_err(|e| emit_error(&app, &status_event, &e))?;
        }
    }

    ssh_session.proxy_chain = proxy_chain.clone();
    Ok((ssh_session, proxy_chain))
}
