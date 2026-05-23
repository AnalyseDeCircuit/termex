//! Bridge-side singleton owning the BackupScheduler task handle (v0.68.0 G1).
//!
//! The scheduler runs in the FRB tokio runtime and persists across unlock
//! events for the life of the process. We start it lazily on the first
//! `cloud_*` call after the DB unlocks; manual `poke` calls let the bridge
//! ask the tick loop to wake up immediately after a `run_now` or `create`.

use once_cell::sync::Lazy;
use std::sync::Mutex;
use termex_core::backup::scheduler::BackupSchedulerHandle;

use crate::db_state;

static HANDLE: Lazy<Mutex<Option<BackupSchedulerHandle>>> = Lazy::new(|| Mutex::new(None));

/// Idempotently spawn the scheduler task. Returns true if it was started by
/// this call. Subsequent calls are no-ops.
pub fn ensure_started() -> bool {
    let mut guard = HANDLE.lock().unwrap();
    if guard.is_some() {
        return false;
    }
    let Some(db) = db_state::arc() else {
        return false;
    };
    let handle = termex_core::backup::scheduler::start_scheduler(db, run_backup);
    *guard = Some(handle);
    true
}

/// Nudge the tick loop. Cheap no-op when the scheduler hasn't started yet.
pub fn poke() {
    if let Some(h) = HANDLE.lock().unwrap().as_ref() {
        h.poke();
    }
}

/// The actual encrypt+write runner the scheduler hands each due row to.
/// Returns the file's size in bytes on success so the history row records
/// the on-disk artifact size — useful for the UI's storage estimate.
fn run_backup(
    row: &termex_core::backup::scheduler::BackupScheduleRow,
    password: String,
) -> Result<i64, String> {
    use time::OffsetDateTime;

    let now = OffsetDateTime::now_utc();
    let stamp = format!(
        "{:04}{:02}{:02}-{:02}{:02}",
        now.year(),
        now.month() as u8,
        now.day(),
        now.hour(),
        now.minute(),
    );
    let file_path = format!(
        "{}/termex-{}-{}.termex",
        row.target_dir.trim_end_matches('/'),
        row.id,
        stamp
    );

    // Best-effort directory creation — the user picked the path; we don't
    // want to fail the backup if a stale `.../backups/` parent vanished
    // since the schedule was created.
    if let Some(parent) = std::path::Path::new(&file_path).parent() {
        let _ = std::fs::create_dir_all(parent);
    }

    // Build the same plaintext envelope `settings_export` uses so backups
    // produced by the scheduler are byte-equivalent to manual ones.
    let payload = crate::api::settings::settings_export_to_json()
        .map_err(|e| format!("collect settings: {e}"))?;

    crate::api::backup::backup_encrypt_to_file(file_path.clone(), password, payload)
        .map_err(|e| format!("encrypt: {e}"))?;

    let size = std::fs::metadata(&file_path)
        .map(|m| m.len() as i64)
        .unwrap_or(0);
    Ok(size)
}
