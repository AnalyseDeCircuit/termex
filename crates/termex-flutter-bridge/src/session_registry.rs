use dashmap::DashMap;
use once_cell::sync::Lazy;
use std::sync::Arc;
use termex_core::sftp::session::SftpHandle;
use termex_core::ssh::channel::ChannelCommand;
use termex_core::ssh::session::SshSession;
use tokio::sync::{mpsc, Mutex as AsyncMutex};

/// Per-session entry holding the command sender plus the live SshSession.
///
/// The SshSession must be kept alive for the duration of the connection —
/// dropping it drops the underlying russh client handle and the shell
/// channel task. We store it behind an async `Mutex<Option<_>>` so that:
/// 1. `close_ssh_session` can take ownership for a graceful disconnect, and
/// 2. SFTP subsystem opens can hold the lock across an `.await`.
///
/// `sftp` caches an opened SFTP subsystem for the session. Wrapped in an
/// `Arc` so clones can outlive the entry-ref lifetime (useful for spawning
/// background transfer tasks without holding the DashMap guard).
/// Both mutexes are wrapped in `Arc` so callers can clone the handle and
/// **drop the DashMap `Ref` before awaiting**. `REGISTRY.get()` returns a
/// guard holding a synchronous shard lock; holding it across an `.await`
/// blocks every other access that hashes to the same shard, which
/// deadlocked SFTP (see `ensure_sftp`). Cloning the `Arc` lets the shard
/// lock be released immediately.
pub struct SessionEntry {
    pub cmd_tx: mpsc::UnboundedSender<ChannelCommand>,
    pub session: Arc<AsyncMutex<Option<SshSession>>>,
    pub sftp: Arc<AsyncMutex<Option<Arc<SftpHandle>>>>,
}

/// Global registry of active SSH sessions, keyed by session_id.
pub static REGISTRY: Lazy<DashMap<String, SessionEntry>> = Lazy::new(DashMap::new);

/// Inserts a new session entry into the registry.
///
/// `cmd_tx` comes from the ChannelHandle produced by `SshSession::open_shell`.
/// `session` is the owning SshSession which must stay alive for the channel
/// task to keep pumping data.
pub fn insert(
    session_id: String,
    cmd_tx: mpsc::UnboundedSender<ChannelCommand>,
    session: SshSession,
) {
    REGISTRY.insert(
        session_id,
        SessionEntry {
            cmd_tx,
            session: Arc::new(AsyncMutex::new(Some(session))),
            sftp: Arc::new(AsyncMutex::new(None)),
        },
    );
}

/// Inserts a cmd_tx-only entry for callers that do not own the SshSession
/// (e.g. tests, or future multiplexed channels that reuse an existing
/// connection). The session slot remains empty.
pub fn insert_cmd_only(session_id: String, cmd_tx: mpsc::UnboundedSender<ChannelCommand>) {
    REGISTRY.insert(
        session_id,
        SessionEntry {
            cmd_tx,
            session: Arc::new(AsyncMutex::new(None)),
            sftp: Arc::new(AsyncMutex::new(None)),
        },
    );
}

/// Sends a command to the session. Returns Err if session not found or channel closed.
pub fn send(session_id: &str, cmd: ChannelCommand) -> Result<(), String> {
    let entry = REGISTRY
        .get(session_id)
        .ok_or_else(|| format!("session not found: {session_id}"))?;
    entry
        .cmd_tx
        .send(cmd)
        .map_err(|_| format!("session channel closed: {session_id}"))
}

/// Takes the owned SshSession out of the entry, leaving a cmd-only shell.
/// Used by `close_ssh_session` to perform a graceful disconnect.
pub async fn take_session(session_id: &str) -> Option<SshSession> {
    // Clone the Arc and release the DashMap shard guard before awaiting —
    // see the SessionEntry doc comment.
    let session_lock = {
        let entry = REGISTRY.get(session_id)?;
        entry.session.clone()
    };
    // Bound to a local: as a tail expression the guard would outlive
    // `session_lock` and fail to borrow-check.
    let taken = session_lock.lock().await.take();
    taken
}

/// Ensures an SFTP subsystem is open for the session; returns a cloneable
/// handle. If the subsystem is already open, the cached handle is returned.
pub async fn ensure_sftp(session_id: &str) -> Result<Arc<SftpHandle>, String> {
    // Clone both Arc'd mutexes, then drop the DashMap `Ref` immediately.
    //
    // Previously the `Ref` was held for the whole function, i.e. across the
    // sftp lock, the session lock, and the `SftpHandle::open` network
    // round-trip. `REGISTRY.get()` holds a *synchronous* shard lock, so any
    // other registry access hashing to the same shard — every terminal
    // read/write, every other SFTP call — blocked behind it. Opening the
    // SFTP pane therefore hung both file panes forever even though the SSH
    // session itself was healthy.
    let (sftp_lock, session_lock) = {
        let entry = REGISTRY
            .get(session_id)
            .ok_or_else(|| format!("SSH session not found: {session_id}"))?;
        (entry.sftp.clone(), entry.session.clone())
    };

    // The sftp lock is held across the open, not just around the check.
    // Releasing it in between let two callers both miss the fast path and both
    // open a subsystem — the UI does exactly that, opening the channel while a
    // directory listing is already in flight. The second handle then replaced
    // the first in the registry, orphaning a live channel whose owner was
    // still awaiting it.
    let mut sftp_guard = sftp_lock.lock().await;

    // Re-check: a caller that was queued on this lock may have just opened it.
    if let Some(handle) = sftp_guard.as_ref() {
        return Ok(handle.clone());
    }

    let session_guard = session_lock.lock().await;
    let session = session_guard
        .as_ref()
        .ok_or_else(|| format!("SSH session {session_id} has been closed"))?;
    let opened = SftpHandle::open(session.handle())
        .await
        .map_err(|e| e.to_string())?;
    drop(session_guard);

    let arc = Arc::new(opened);
    *sftp_guard = Some(arc.clone());
    Ok(arc)
}

/// Closes the SFTP subsystem if one is open. Idempotent.
pub async fn close_sftp(session_id: &str) {
    let sftp_lock = {
        let Some(entry) = REGISTRY.get(session_id) else {
            return;
        };
        entry.sftp.clone()
    };
    let taken = sftp_lock.lock().await.take();
    if let Some(arc) = taken {
        // Best-effort: try to take exclusive ownership and close cleanly.
        if let Ok(handle) = Arc::try_unwrap(arc) {
            let _ = handle.close().await;
        }
    }
}

/// Removes a session entry from the registry.
pub fn remove(session_id: &str) {
    REGISTRY.remove(session_id);
}
