use std::collections::VecDeque;
use std::sync::Mutex;

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
