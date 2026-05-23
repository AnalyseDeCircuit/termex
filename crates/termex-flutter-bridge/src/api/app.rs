use anyhow::{anyhow, Result};
use termex_core::keychain;
use termex_core::paths;
use termex_core::storage::db::Database;

use crate::db_state;

#[derive(Debug, Clone)]
pub struct AppInitState {
    /// true = first run (no DB yet), false = existing DB found.
    pub is_first_run: bool,
}

/// Initialise the application state.
///
/// Steps:
/// 1. Check for a stale lock file from a previous crash, write a new one.
/// 2. If the DB file exists, open it in plaintext mode. The Tauri/Vue
///    schema stores the master password (when set) as a salt + verify token
///    in the `settings` table — the DB file itself is plain SQLite.
/// 3. If no master password row is present, the DB is "open" and we store
///    it in the global db_state so all subsequent API calls work without
///    prompting the user.
/// 4. If a master password IS configured, we leave db_state empty and tell
///    the UI to show the unlock dialog.
///
/// Returns `Err("AnotherInstanceRunning")` if another Termex process is live.
pub fn init_app() -> Result<AppInitState> {
    let db_path = paths::db_path();
    let lock_path = paths::lock_path();

    if lock_path.exists() {
        let pid_str = std::fs::read_to_string(&lock_path).unwrap_or_default();
        let pid: u32 = pid_str.trim().parse().unwrap_or(0);
        if pid > 0 && process_alive(pid) {
            return Err(anyhow!("AnotherInstanceRunning: pid={}", pid));
        }
        // Stale lock from a crashed instance — clear it.
        let _ = std::fs::remove_file(&lock_path);
    }

    // Ensure parent directory exists.
    if let Some(parent) = lock_path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::write(&lock_path, std::process::id().to_string())?;

    // Initialize the OS-keychain credential cache. This is the only call
    // path that hits the real OS keychain — at most one password prompt
    // per app launch (see termex_core::keychain docs). enable_flush()
    // permits subsequent writes by store()/delete() to land back in the
    // OS keychain.
    let _ = keychain::init();
    keychain::enable_flush();

    let is_first_run = !db_path.exists();

    // First run: defer DB creation until the user either sets a master
    // password or explicitly skips that step. Nothing to unlock yet.
    if is_first_run {
        return Ok(AppInitState { is_first_run: true });
    }

    // Existing DB: open it plaintext. The Tauri build stores `master_salt`
    // in the settings table only when the user explicitly sets a master
    // password. If no master password row is present, auto-unlock now so
    // the UI doesn't show a useless unlock dialog.
    let db = Database::open(None)
        .map_err(|e| anyhow!("Failed to open database: {}", e))?;
    if !master_password_set(&db) {
        db_state::set_db(db);
    }
    // If a master password IS set, drop `db` here — verify_master_password()
    // will reopen it after the user authenticates.

    Ok(AppInitState { is_first_run: false })
}

/// Returns true when an existing master password must be entered before the
/// rest of the app is usable. Returns false when either:
///   - this is a first run (no DB yet), or
///   - the DB exists but has no `master_salt` row (no master password set),
///     in which case [`init_app`] has already auto-opened it.
pub fn master_password_required() -> bool {
    // If init_app auto-unlocked, the DB is already in db_state and no
    // password is required.
    if db_state::is_unlocked() {
        return false;
    }
    // DB not yet opened: it either doesn't exist (first run, no password
    // required) or it has a master_salt row.
    let db_path = paths::db_path();
    if !db_path.exists() {
        return false;
    }
    match Database::open(None) {
        Ok(db) => master_password_set(&db),
        Err(_) => false,
    }
}

/// Shut down gracefully: remove lock file and flush in-memory state.
pub fn close_app() -> Result<()> {
    let _ = std::fs::remove_file(paths::lock_path());
    Ok(())
}

/// Returns true if the `settings` table contains a `master_salt` row.
fn master_password_set(db: &Database) -> bool {
    db.with_conn(|conn| {
        let mut stmt =
            conn.prepare("SELECT 1 FROM settings WHERE key = 'master_salt'")?;
        Ok(stmt.exists([])?)
    })
    .unwrap_or(false)
}

/// Returns true if a process with the given PID is currently running.
fn process_alive(pid: u32) -> bool {
    #[cfg(unix)]
    {
        std::process::Command::new("kill")
            .args(["-0", &pid.to_string()])
            .status()
            .map(|s| s.success())
            .unwrap_or(false)
    }
    #[cfg(windows)]
    {
        std::process::Command::new("tasklist")
            .args(["/FI", &format!("PID eq {}", pid), "/NH"])
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).contains(&pid.to_string()))
            .unwrap_or(false)
    }
}
