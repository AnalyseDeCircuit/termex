use std::collections::VecDeque;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use dashmap::DashMap;
use once_cell::sync::Lazy;
use termex_core::sftp::event_emitter::SftpEventEmitter;

/// Transfer-progress event delivered to the Flutter side.
///
/// Mirrors `api::sftp::TransferProgress` but kept in the emitter module to
/// avoid a circular dependency between the API layer and the event layer.
#[derive(Debug, Clone)]
pub struct SftpTransferProgress {
    pub transfer_id: String,
    pub remote_path: String,
    pub bytes_transferred: u64,
    pub total_bytes: u64,
    pub done: bool,
    pub error: Option<String>,
}

/// Per-transfer progress queue.
///
/// Dart polls `poll_sftp_progress(transfer_id)` to drain pending updates.
/// This mirrors the SSH emitter's pull-based model (see frb_ssh_emitter).
static PROGRESS_QUEUES: Lazy<DashMap<String, Mutex<VecDeque<SftpTransferProgress>>>> =
    Lazy::new(DashMap::new);

/// Registers an empty queue for a new transfer. Called from `sftp_download`
/// / `sftp_upload` when the async task spawns.
pub fn register_transfer(transfer_id: String) {
    PROGRESS_QUEUES.insert(transfer_id, Mutex::new(VecDeque::new()));
}

/// Removes the queue after the final event has been delivered.
pub fn unregister_transfer(transfer_id: &str) {
    PROGRESS_QUEUES.remove(transfer_id);
    CANCEL_FLAGS.remove(transfer_id);
}

/// Per-transfer cancel/pause flags (P1.6).
///
/// `sftp_pause_transfer` flips the flag; the running download/upload loop
/// checks it before each chunk and exits cleanly. `sftp_resume_transfer`
/// re-arms the flag (sets to false) and spawns a fresh task that calls the
/// resumable variant with the previously transferred byte count as offset.
static CANCEL_FLAGS: Lazy<DashMap<String, Arc<AtomicBool>>> = Lazy::new(DashMap::new);

/// Returns (and inserts if missing) the cancel flag for a transfer.
pub fn cancel_flag(transfer_id: &str) -> Arc<AtomicBool> {
    if let Some(existing) = CANCEL_FLAGS.get(transfer_id) {
        return existing.clone();
    }
    let flag = Arc::new(AtomicBool::new(false));
    CANCEL_FLAGS.insert(transfer_id.to_string(), flag.clone());
    flag
}

/// Sets the cancel flag to `paused`. Returns true if a flag existed.
pub fn set_paused(transfer_id: &str, paused: bool) -> bool {
    if let Some(flag) = CANCEL_FLAGS.get(transfer_id) {
        flag.store(paused, Ordering::Relaxed);
        true
    } else {
        false
    }
}

/// Drains the per-transfer queue. Returns all events queued since the last
/// call. Called by Dart at 16ms intervals for smooth progress-bar updates.
pub fn drain(transfer_id: &str) -> Vec<SftpTransferProgress> {
    let Some(entry) = PROGRESS_QUEUES.get(transfer_id) else {
        return Vec::new();
    };
    let Ok(mut q) = entry.lock() else {
        return Vec::new();
    };
    q.drain(..).collect()
}

fn enqueue(transfer_id: &str, progress: SftpTransferProgress) {
    if let Some(entry) = PROGRESS_QUEUES.get(transfer_id) {
        if let Ok(mut q) = entry.lock() {
            q.push_back(progress);
        }
    }
}

/// FRB-side implementation of `SftpEventEmitter`.
pub struct FrbSftpEmitter;

impl SftpEventEmitter for FrbSftpEmitter {
    fn emit_progress(&self, transfer_id: &str, remote_path: &str, transferred: u64, total: u64) {
        enqueue(
            transfer_id,
            SftpTransferProgress {
                transfer_id: transfer_id.to_string(),
                remote_path: remote_path.to_string(),
                bytes_transferred: transferred,
                total_bytes: total,
                done: false,
                error: None,
            },
        );
    }

    fn emit_done(&self, transfer_id: &str, remote_path: &str, total: u64) {
        enqueue(
            transfer_id,
            SftpTransferProgress {
                transfer_id: transfer_id.to_string(),
                remote_path: remote_path.to_string(),
                bytes_transferred: total,
                total_bytes: total,
                done: true,
                error: None,
            },
        );
    }

    fn emit_error(&self, transfer_id: &str, error: &str) {
        enqueue(
            transfer_id,
            SftpTransferProgress {
                transfer_id: transfer_id.to_string(),
                remote_path: String::new(),
                bytes_transferred: 0,
                total_bytes: 0,
                done: true,
                error: Some(error.to_string()),
            },
        );
    }
}
