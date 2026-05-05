use std::sync::Arc;

use chrono::Utc;
use termex_core::ssh::auth;
use termex_core::ssh::channel::ChannelCommand;
use termex_core::ssh::host_key::{self, HostKeyVerifyResult};
use termex_core::ssh::session::SshSession;
use termex_core::storage::models::AuthType;

use crate::frb_ssh_emitter::{self, FrbSshEmitter, SshStreamEvent};
use crate::session_registry;

/// Minimal server row used for establishing a connection. Pulled directly
/// from the `servers` table without passing through `ServerDto` (which
/// omits credential paths on the serialization boundary).
struct ConnectRow {
    host: String,
    port: i32,
    username: String,
    auth_type: String,
    key_path: Option<String>,
}

fn load_connect_row(server_id: &str) -> Result<ConnectRow, String> {
    crate::db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.query_row(
                "SELECT host, port, username, auth_type, key_path
                 FROM servers WHERE id = ?1",
                rusqlite::params![server_id],
                |row| {
                    Ok(ConnectRow {
                        host: row.get(0)?,
                        port: row.get(1)?,
                        username: row.get(2)?,
                        auth_type: row.get(3)?,
                        key_path: row.get(4)?,
                    })
                },
            )
        })
        .map_err(|e| e.to_string())
    })
}

/// Touches the `last_connected` column on success. Errors are swallowed —
/// a connected session is more important than a bookkeeping write.
fn mark_last_connected(server_id: &str) {
    let now = Utc::now().to_rfc3339();
    let _ = crate::db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "UPDATE servers SET last_connected = ?1, updated_at = ?1 WHERE id = ?2",
                rusqlite::params![now, server_id],
            )?;
            Ok::<(), rusqlite::Error>(())
        })
        .map_err(|e| e.to_string())
    });
}

async fn connect_direct(
    server_id: &str,
    row: &ConnectRow,
    emitter: Arc<FrbSshEmitter>,
    cols: u32,
    rows: u32,
    session_id: &str,
) -> Result<SshSession, String> {
    let mut session = SshSession::connect(&row.host, row.port as u16)
        .await
        .map_err(|e| e.to_string())?;

    // TOFU host key verification: only reject on an outright key change.
    // NewHost is silently trusted (matches legacy Tauri behaviour), and any
    // DB error degrades to "trust this time" rather than blocking connect.
    if let Some(pubkey) = session.captured_host_key() {
        let verify: HostKeyVerifyResult = crate::db_state::with_db(|db| {
            Ok(host_key::verify_host_key(db, &row.host, row.port as u16, &pubkey))
        })?;
        match verify {
            HostKeyVerifyResult::Trusted => {}
            HostKeyVerifyResult::NewHost { .. } => {
                let _ = crate::db_state::with_db(|db| {
                    host_key::trust_host_key(db, &row.host, row.port as u16, &pubkey)
                        .map_err(|e| e.to_string())
                });
            }
            HostKeyVerifyResult::KeyChanged { .. } => {
                let _ = session.disconnect().await;
                return Err(
                    "host key changed since last connection; aborting for safety".into(),
                );
            }
        }
    }

    // Authenticate.
    let auth_ty = AuthType::from_str(&row.auth_type)
        .ok_or_else(|| format!("unknown auth_type: {}", row.auth_type))?;
    match auth_ty {
        AuthType::Password => {
            let password = termex_core::keychain::get(
                &termex_core::keychain::ssh_password_key(server_id),
            )
            .map_err(|e| format!("failed to read keychain password: {e}"))?;
            auth::auth_password(session.handle_mut(), &row.username, &password)
                .await
                .map_err(|e| e.to_string())?;
        }
        AuthType::Key => {
            let key_path = row
                .key_path
                .as_deref()
                .ok_or_else(|| "auth_type=key but key_path is empty".to_string())?;
            let key_data = std::fs::read_to_string(key_path)
                .map_err(|e| format!("failed to read key file {key_path}: {e}"))?;
            let passphrase = termex_core::keychain::get(
                &termex_core::keychain::ssh_passphrase_key(server_id),
            )
            .ok();
            auth::auth_key_data(
                session.handle_mut(),
                &row.username,
                &key_data,
                passphrase.as_deref(),
            )
            .await
            .map_err(|e| e.to_string())?;
        }
    }

    session
        .open_shell(emitter, session_id.to_string(), cols, rows)
        .await
        .map_err(|e| e.to_string())?;

    Ok(session)
}

/// Opens an SSH session and starts streaming terminal events to a
/// per-session queue that Dart polls via `poll_ssh_events`.
///
/// Scope (v0.50.x): direct TCP connection + password or key auth against
/// the server's stored credentials. Chain-through-bastion and network
/// proxies remain routed through the legacy Tauri path; see
/// `docs/tech-debt.md` T-9 for the follow-up plan.
pub async fn open_ssh_session(
    server_id: String,
    cols: u32,
    rows: u32,
) -> Result<String, String> {
    let session_id = uuid::Uuid::new_v4().to_string();
    frb_ssh_emitter::register_session(session_id.clone());

    let row = match load_connect_row(&server_id) {
        Ok(r) => r,
        Err(e) => {
            frb_ssh_emitter::unregister_session(&session_id);
            return Err(e);
        }
    };

    let emitter = Arc::new(FrbSshEmitter);
    let session = match connect_direct(&server_id, &row, emitter, cols, rows, &session_id).await {
        Ok(s) => s,
        Err(e) => {
            frb_ssh_emitter::unregister_session(&session_id);
            return Err(e);
        }
    };

    let cmd_tx = session
        .channel_cmd_tx()
        .ok_or_else(|| "shell channel opened without command sender".to_string())?;

    session_registry::insert(session_id.clone(), cmd_tx, session);
    mark_last_connected(&server_id);

    Ok(session_id)
}

/// Drains pending events for a session. Called by the Dart polling task.
pub fn poll_ssh_events(session_id: String) -> Vec<SshStreamEvent> {
    frb_ssh_emitter::drain(&session_id)
}

/// Sends raw bytes to the shell stdin of the given session.
pub fn write_stdin(session_id: String, data: Vec<u8>) -> Result<(), String> {
    session_registry::send(&session_id, ChannelCommand::Write(data))
}

/// Resizes the pseudo-terminal of the given session.
pub fn resize_terminal(session_id: String, cols: u32, rows: u32) -> Result<(), String> {
    session_registry::send(&session_id, ChannelCommand::Resize(cols, rows))
}

/// Closes the shell channel of the given session and removes it from the
/// registry. Idempotent — does nothing if the session is not found.
pub async fn close_ssh_session(session_id: String) -> Result<(), String> {
    // Signal the channel task to exit. Errors are tolerated: the session
    // may have already died on the server side.
    let _ = session_registry::send(&session_id, ChannelCommand::Close);

    // Close any open SFTP subsystem first.
    session_registry::close_sftp(&session_id).await;

    // Gracefully disconnect the russh client, dropping the task.
    if let Some(session) = session_registry::take_session(&session_id).await {
        let _ = session.disconnect().await;
    }

    session_registry::remove(&session_id);
    frb_ssh_emitter::unregister_session(&session_id);
    Ok(())
}

/// Checks whether an SSH agent is available by inspecting `SSH_AUTH_SOCK`.
pub fn check_ssh_agent_available() -> Result<bool, String> {
    let sock = std::env::var("SSH_AUTH_SOCK").unwrap_or_default();
    if sock.is_empty() {
        return Ok(false);
    }
    Ok(std::path::Path::new(&sock).exists())
}

/// Opens a new session to the same server as an existing session.
///
/// v0.50.x: re-resolves the server from its last-connected record. True
/// channel multiplexing over a shared russh handle is tracked in tech
/// debt T-9 and will land with the proxy-chain migration.
pub async fn open_ssh_session_clone(
    existing_session_id: String,
    cols: u32,
    rows: u32,
) -> Result<String, String> {
    let server_id = crate::db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.query_row::<String, _, _>(
                "SELECT id FROM servers
                 WHERE last_connected IS NOT NULL
                 ORDER BY last_connected DESC LIMIT 1",
                [],
                |row| row.get(0),
            )
        })
        .map_err(|e| e.to_string())
    })
    .map_err(|e| format!("clone: unable to resolve source server ({existing_session_id}): {e}"))?;

    open_ssh_session(server_id, cols, rows).await
}

/// Checks the host-key status for a connection by querying the `known_hosts` table.
///
/// Returns one of:
/// - `"trusted"` — fingerprint matches the stored record.
/// - `"new:{fingerprint}"` — host not yet in the database.
/// - `"changed:{old_fingerprint}:{new_fingerprint}"` — host known but fingerprint differs.
pub fn check_host_key(
    host: String,
    port: u16,
    fingerprint: String,
    key_type: String,
) -> Result<String, String> {
    let _ = key_type; // key_type not used in the lookup; stored when trusting
    crate::db_state::with_db(|db| {
        db.with_conn(|conn| {
            let result: rusqlite::Result<(String, String)> = conn.query_row(
                "SELECT fingerprint, key_type FROM known_hosts WHERE host = ?1 AND port = ?2",
                rusqlite::params![host, port as i32],
                |row| Ok((row.get(0)?, row.get(1)?)),
            );
            match result {
                Ok((stored_fp, _stored_type)) => {
                    if stored_fp == fingerprint {
                        Ok("trusted".into())
                    } else {
                        Ok(format!("changed:{}:{}", stored_fp, fingerprint))
                    }
                }
                Err(rusqlite::Error::QueryReturnedNoRows) => {
                    Ok(format!("new:{}", fingerprint))
                }
                Err(e) => Err(e),
            }
        })
        .map_err(|e| e.to_string())
    })
}

/// Adds or updates a host-key entry in the `known_hosts` table.
///
/// Uses `INSERT OR REPLACE` to handle both new hosts and key rotation while
/// preserving the original `first_seen` timestamp.
pub fn trust_host_key(
    host: String,
    port: u16,
    fingerprint: String,
    key_type: String,
) -> Result<(), String> {
    let now = Utc::now().to_rfc3339();
    crate::db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "INSERT OR REPLACE INTO known_hosts
                    (host, port, key_type, fingerprint, first_seen, last_seen)
                 VALUES (
                     ?1, ?2, ?3, ?4,
                     COALESCE(
                         (SELECT first_seen FROM known_hosts WHERE host = ?1 AND port = ?2),
                         ?5
                     ),
                     ?5
                 )",
                rusqlite::params![host, port as i32, key_type, fingerprint, now],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}
