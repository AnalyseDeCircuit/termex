//! SFTP operations exposed to Flutter via FRB.
//!
//! Session-id keyed — the caller must first hold a live SSH session from
//! `api::ssh::open_ssh_session`. `open_sftp_channel` lazily opens an SFTP
//! subsystem over the existing SSH handle and caches it on the
//! [`session_registry::SessionEntry`] so subsequent calls are cheap.
//!
//! Progress reporting uses the same pull-based queue pattern as SSH:
//! transfers write to [`frb_sftp_emitter::PROGRESS_QUEUES`] and Dart polls
//! via [`poll_sftp_progress`] on a 16ms timer.

use std::sync::Arc;

use termex_core::sftp::event_emitter::{BoxedSftpEmitter, SftpEventEmitter};
use termex_core::sftp::session::transfer_between;

use crate::frb_sftp_emitter::{self, FrbSftpEmitter, SftpTransferProgress};
use crate::session_registry;

// ─── DTOs ────────────────────────────────────────────────────────────────────

/// A remote filesystem entry returned by [sftp_list].
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SftpFileDto {
    pub name: String,
    pub path: String,
    pub is_dir: bool,
    pub is_symlink: bool,
    /// File size in bytes.
    pub size: u64,
    /// Unix permission bits (e.g. 0o644).
    pub permissions: u32,
    /// Seconds since Unix epoch.
    pub modified_at: i64,
    /// Owner username (or uid as string), if available.
    pub owner: Option<String>,
    /// Group name (or gid as string), if available.
    pub group: Option<String>,
}

// ─── Session lifecycle ────────────────────────────────────────────────────────

/// Opens (or reuses) an SFTP channel on an existing SSH session.
/// Returns the canonical remote working directory.
pub async fn open_sftp_channel(session_id: String) -> Result<String, String> {
    let handle = session_registry::ensure_sftp(&session_id).await?;
    // `.` canonicalises to the current working directory on the remote — this
    // is typically the user's $HOME on fresh logins.
    handle.canonicalize(".").await.map_err(|e| e.to_string())
}

/// Closes the SFTP channel for `session_id`.
pub async fn close_sftp_channel(session_id: String) -> Result<(), String> {
    session_registry::close_sftp(&session_id).await;
    Ok(())
}

/// Returns `true` if an SFTP channel is currently cached for `session_id`.
pub async fn is_sftp_open(session_id: String) -> bool {
    // Clone the Arc'd mutex and release the DashMap shard guard before
    // awaiting — holding it across `.await` blocks every registry access
    // on the same shard (see `SessionEntry`).
    let sftp_lock = {
        let Some(entry) = session_registry::REGISTRY.get(&session_id) else {
            return false;
        };
        entry.sftp.clone()
    };
    // Bound to a local: as a tail expression the guard would outlive
    // `sftp_lock` and fail to borrow-check.
    let open = sftp_lock.lock().await.is_some();
    open
}

// ─── Directory operations ─────────────────────────────────────────────────────

fn permissions_to_mode(perm_str: &Option<String>) -> u32 {
    // russh-sftp renders permissions as a Unix ls-style string like
    // "rwxr-xr-x". Parse back to a mode bitset for the Dart layer. Any
    // parse failure degrades to 0o644 which the UI treats as unknown.
    let Some(s) = perm_str else { return 0o644 };
    let bytes = s.as_bytes();
    if bytes.len() < 9 {
        return 0o644;
    }
    let bit = |i: usize, c: u8| if bytes[i] == c { 1u32 } else { 0u32 };
    let user = (bit(0, b'r') << 2) | (bit(1, b'w') << 1) | bit(2, b'x');
    let group = (bit(3, b'r') << 2) | (bit(4, b'w') << 1) | bit(5, b'x');
    let other = (bit(6, b'r') << 2) | (bit(7, b'w') << 1) | bit(8, b'x');
    (user << 6) | (group << 3) | other
}

/// Lists the contents of `path` on the remote, sorted dirs-first.
pub async fn sftp_list(
    session_id: String,
    path: String,
) -> Result<Vec<SftpFileDto>, String> {
    let handle = session_registry::ensure_sftp(&session_id).await?;
    let entries = handle.list_dir(&path).await.map_err(|e| e.to_string())?;
    let mut out: Vec<SftpFileDto> = entries
        .into_iter()
        .map(|e| {
            let full = if path.ends_with('/') {
                format!("{path}{}", e.name)
            } else {
                format!("{path}/{}", e.name)
            };
            SftpFileDto {
                name: e.name,
                path: full,
                is_dir: e.is_dir,
                is_symlink: e.is_symlink,
                size: e.size,
                permissions: permissions_to_mode(&e.permissions),
                modified_at: e.mtime.unwrap_or(0) as i64,
                owner: e.uid.map(|u| u.to_string()),
                group: e.gid.map(|g| g.to_string()),
            }
        })
        .collect();
    out.sort_by(|a, b| match (a.is_dir, b.is_dir) {
        (true, false) => std::cmp::Ordering::Less,
        (false, true) => std::cmp::Ordering::Greater,
        _ => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
    });
    Ok(out)
}

/// Creates a remote directory.
pub async fn sftp_mkdir(session_id: String, path: String) -> Result<(), String> {
    let handle = session_registry::ensure_sftp(&session_id).await?;
    handle.mkdir(&path).await.map_err(|e| e.to_string())
}

/// Deletes a remote file.
pub async fn sftp_remove(session_id: String, path: String) -> Result<(), String> {
    let handle = session_registry::ensure_sftp(&session_id).await?;
    handle.remove_file(&path).await.map_err(|e| e.to_string())
}

/// Deletes a remote directory. Non-recursive — the UI must walk children
/// and delete them first. A recursive variant will land in v0.51.
pub async fn sftp_rmdir(session_id: String, path: String) -> Result<(), String> {
    let handle = session_registry::ensure_sftp(&session_id).await?;
    handle.remove_dir(&path).await.map_err(|e| e.to_string())
}

/// Renames (moves) a remote path.
pub async fn sftp_rename(
    session_id: String,
    from: String,
    to: String,
) -> Result<(), String> {
    let handle = session_registry::ensure_sftp(&session_id).await?;
    handle.rename(&from, &to).await.map_err(|e| e.to_string())
}

/// Changes the Unix permission bits of a remote file (chmod).
///
/// GitHub issue #24: now functional via russh-sftp 2.1.1's `set_metadata`
/// (SSH_FXP_SETSTAT). `mode` is the octal permission value, e.g. 0o755.
pub async fn sftp_chmod(
    session_id: String,
    path: String,
    mode: u32,
) -> Result<(), String> {
    let handle = session_registry::ensure_sftp(&session_id).await?;
    handle.chmod(&path, mode).await.map_err(|e| e.to_string())
}

/// Changes the owner (uid) and group (gid) of a remote file (chown).
///
/// GitHub issue #24 (chown half): sends numeric uid/gid via SETSTAT. The
/// remote SFTP account usually must be root; a server-side permission
/// denial surfaces as an `Err` string the Flutter UI can display.
pub async fn sftp_chown(
    session_id: String,
    path: String,
    uid: u32,
    gid: u32,
) -> Result<(), String> {
    let handle = session_registry::ensure_sftp(&session_id).await?;
    handle
        .chown(&path, uid, gid)
        .await
        .map_err(|e| e.to_string())
}

/// Canonicalises a remote path (resolves `~`, symlinks, `..`).
pub async fn sftp_canonicalize(
    session_id: String,
    path: String,
) -> Result<String, String> {
    let handle = session_registry::ensure_sftp(&session_id).await?;
    handle.canonicalize(&path).await.map_err(|e| e.to_string())
}

// ─── Transfer operations ──────────────────────────────────────────────────────

/// Downloads a remote file to `local_path`. Returns immediately; progress
/// is delivered via [`poll_sftp_progress`].
///
/// `offset` lets the Dart side resume a paused transfer by passing in the
/// already-transferred byte count. A fresh transfer should pass `0`.
/// Reads a small file entirely into memory. Used by the inline file editor
/// dialog. Refuses to read if the file size exceeds `max_bytes`.
pub async fn sftp_read_file_bytes(
    session_id: String,
    path: String,
    max_bytes: u32,
) -> Result<Vec<u8>, String> {
    let handle = session_registry::ensure_sftp(&session_id)
        .await
        .map_err(|e| e.to_string())?;
    let data = handle
        .read_file(&path)
        .await
        .map_err(|e| e.to_string())?;
    if data.len() > max_bytes as usize {
        return Err(format!(
            "file too large: {} bytes (max {})",
            data.len(),
            max_bytes
        ));
    }
    Ok(data)
}

/// Writes the in-memory editor buffer back to `path` (create-or-truncate).
pub async fn sftp_write_file_bytes(
    session_id: String,
    path: String,
    data: Vec<u8>,
) -> Result<(), String> {
    let handle = session_registry::ensure_sftp(&session_id)
        .await
        .map_err(|e| e.to_string())?;
    handle
        .write_file(&path, &data)
        .await
        .map_err(|e| e.to_string())
}

pub async fn sftp_download(
    session_id: String,
    remote_path: String,
    local_path: String,
    transfer_id: String,
    offset: u64,
) -> Result<(), String> {
    let handle = session_registry::ensure_sftp(&session_id).await?;
    frb_sftp_emitter::register_transfer(transfer_id.clone());
    let cancel = frb_sftp_emitter::cancel_flag(&transfer_id);
    cancel.store(false, std::sync::atomic::Ordering::Relaxed);
    let emitter: BoxedSftpEmitter = Arc::new(FrbSftpEmitter);
    let tid = transfer_id.clone();
    tokio::spawn(async move {
        let err_emitter = emitter.clone();
        if let Err(e) = handle
            .download_resumable(&remote_path, &local_path, &tid, &emitter, offset, Some(cancel))
            .await
        {
            err_emitter.emit_error(&tid, &e.to_string());
        }
    });
    Ok(())
}

/// Uploads a local file to `remote_path`.
pub async fn sftp_upload(
    session_id: String,
    local_path: String,
    remote_path: String,
    transfer_id: String,
    offset: u64,
) -> Result<(), String> {
    let handle = session_registry::ensure_sftp(&session_id).await?;
    frb_sftp_emitter::register_transfer(transfer_id.clone());
    let cancel = frb_sftp_emitter::cancel_flag(&transfer_id);
    cancel.store(false, std::sync::atomic::Ordering::Relaxed);
    let emitter: BoxedSftpEmitter = Arc::new(FrbSftpEmitter);
    let tid = transfer_id.clone();
    tokio::spawn(async move {
        let err_emitter = emitter.clone();
        if let Err(e) = handle
            .upload_resumable(&local_path, &remote_path, &tid, &emitter, offset, Some(cancel))
            .await
        {
            err_emitter.emit_error(&tid, &e.to_string());
        }
    });
    Ok(())
}

/// Cooperatively pauses a running transfer (P1.6). The download/upload loop
/// checks the flag before each chunk and exits cleanly without emitting
/// `done`. Resume by calling [`sftp_download`] / [`sftp_upload`] again with
/// the latest `transferredBytes` as `offset`.
pub fn sftp_pause_transfer(transfer_id: String) -> Result<(), String> {
    frb_sftp_emitter::set_paused(&transfer_id, true);
    Ok(())
}

/// Clears the paused flag for a transfer so a fresh
/// [`sftp_download`] / [`sftp_upload`] call can begin running. Idempotent.
pub fn sftp_resume_transfer(transfer_id: String) -> Result<(), String> {
    frb_sftp_emitter::set_paused(&transfer_id, false);
    Ok(())
}

/// Streams a file from one SFTP session to another (server-to-server copy).
pub async fn sftp_transfer_between(
    src_session_id: String,
    src_path: String,
    dst_session_id: String,
    dst_path: String,
    transfer_id: String,
) -> Result<(), String> {
    let src = session_registry::ensure_sftp(&src_session_id).await?;
    let dst = session_registry::ensure_sftp(&dst_session_id).await?;
    frb_sftp_emitter::register_transfer(transfer_id.clone());
    let emitter: BoxedSftpEmitter = Arc::new(FrbSftpEmitter);
    let tid = transfer_id.clone();
    tokio::spawn(async move {
        let err_emitter = emitter.clone();
        if let Err(e) = transfer_between(&src, &src_path, &dst, &dst_path, &tid, &emitter).await {
            err_emitter.emit_error(&tid, &e.to_string());
        }
    });
    Ok(())
}

/// Polls the progress queue for a given transfer. Drains pending updates
/// and returns them in chronological order.
pub fn poll_sftp_progress(transfer_id: String) -> Vec<SftpTransferProgress> {
    let events = frb_sftp_emitter::drain(&transfer_id);
    // If the terminal event was delivered, unregister the queue so memory
    // is reclaimed.
    if events.iter().any(|e| e.done) {
        frb_sftp_emitter::unregister_transfer(&transfer_id);
    }
    events
}

/// Cancels an in-flight transfer identified by `transfer_id`.
///
/// v0.50.x: no-op. russh-sftp reads/writes are not cancellable mid-chunk;
/// a proper implementation needs a CancellationToken plumbed through the
/// transfer loop. Tracked as a small follow-up.
pub fn sftp_cancel_transfer(transfer_id: String) -> Result<(), String> {
    let _ = transfer_id;
    Ok(())
}

// ─── Command history ──────────────────────────────────────────────────────────

/// A record of a single shell command (OSC 133 tracking).
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CommandHistoryEntry {
    pub id: String,
    pub session_id: String,
    pub server_id: Option<String>,
    pub command: String,
    pub exit_code: Option<i32>,
    pub started_at: String,
    pub duration_ms: Option<i64>,
}

/// Records a completed command in the `command_history` table.
pub fn record_command(
    session_id: String,
    server_id: Option<String>,
    command: String,
    exit_code: Option<i32>,
    started_at: String,
    duration_ms: Option<i64>,
) -> Result<String, String> {
    let id = uuid::Uuid::new_v4().to_string();
    crate::db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "INSERT INTO command_history (id, session_id, server_id, command, exit_code, started_at, duration_ms)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                rusqlite::params![
                    id,
                    session_id,
                    server_id,
                    command,
                    exit_code,
                    started_at,
                    duration_ms,
                ],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })?;
    Ok(id)
}

/// Returns the most recent `limit` commands for `server_id`, newest first.
pub fn list_command_history(
    server_id: String,
    limit: u32,
) -> Result<Vec<CommandHistoryEntry>, String> {
    crate::db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, session_id, server_id, command, exit_code, started_at, duration_ms
                 FROM command_history
                 WHERE server_id = ?1
                 ORDER BY started_at DESC
                 LIMIT ?2",
            )?;
            let rows = stmt.query_map(rusqlite::params![server_id, limit], |row| {
                Ok(CommandHistoryEntry {
                    id: row.get(0)?,
                    session_id: row.get(1)?,
                    server_id: row.get(2)?,
                    command: row.get(3)?,
                    exit_code: row.get(4)?,
                    started_at: row.get(5)?,
                    duration_ms: row.get(6)?,
                })
            })?;
            rows.collect::<rusqlite::Result<Vec<_>>>()
        })
        .map_err(|e| e.to_string())
    })
}

/// Clears all command history for `server_id`.
pub fn clear_command_history(server_id: String) -> Result<(), String> {
    crate::db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "DELETE FROM command_history WHERE server_id = ?1",
                rusqlite::params![server_id],
            )?;
            Ok::<(), rusqlite::Error>(())
        })
        .map_err(|e| e.to_string())
    })
}

// ─── Test helpers ─────────────────────────────────────────────────────────────

/// Returns the canonical home directory for tests that cannot open a real
/// SFTP subsystem. Matches the behaviour of the previous in-memory stub.
pub fn _test_insert_session(_session_id: &str) {
    // No-op: the real implementation opens SFTP lazily via `ensure_sftp`.
    // Tests that exercise stubs should mock at the session_registry level.
}

pub fn _test_clear_registry() {
    // No-op for compatibility; real clearing happens via `close_ssh_session`.
}
