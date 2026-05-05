use anyhow::{anyhow, Result};
use termex_core::paths;

#[derive(Debug, Clone)]
pub struct AppInitState {
    /// true = first run (no DB yet), false = existing DB found.
    pub is_first_run: bool,
}

/// Initialise the application state without unlocking SQLCipher.
///
/// Checks for a stale lock file from a previous crash, writes a new one,
/// and returns whether this is a first-time installation.
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

    Ok(AppInitState {
        is_first_run: !db_path.exists(),
    })
}

/// Shut down gracefully: remove lock file and flush in-memory state.
pub fn close_app() -> Result<()> {
    let _ = std::fs::remove_file(paths::lock_path());
    Ok(())
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
