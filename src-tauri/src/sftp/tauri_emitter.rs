use tauri::{AppHandle, Emitter};
use termex_core::sftp::event_emitter::SftpEventEmitter;
use termex_core::sftp::session::TransferProgress;

/// Tauri implementation of `SftpEventEmitter`.
///
/// Emits transfer progress via `tauri::AppHandle` under the legacy event
/// names `sftp://progress/{transfer_id}` that the Vue frontend listens on.
pub struct TauriSftpEmitter(pub AppHandle);

impl SftpEventEmitter for TauriSftpEmitter {
    fn emit_progress(&self, transfer_id: &str, remote_path: &str, transferred: u64, total: u64) {
        let event = format!("sftp://progress/{transfer_id}");
        let _ = self.0.emit(
            &event,
            TransferProgress {
                transfer_id: transfer_id.to_string(),
                remote_path: remote_path.to_string(),
                transferred,
                total,
                done: false,
                error: None,
            },
        );
    }

    fn emit_done(&self, transfer_id: &str, remote_path: &str, total: u64) {
        let event = format!("sftp://progress/{transfer_id}");
        let _ = self.0.emit(
            &event,
            TransferProgress {
                transfer_id: transfer_id.to_string(),
                remote_path: remote_path.to_string(),
                transferred: total,
                total,
                done: true,
                error: None,
            },
        );
    }

    fn emit_error(&self, transfer_id: &str, error: &str) {
        let event = format!("sftp://progress/{transfer_id}");
        let _ = self.0.emit(
            &event,
            TransferProgress {
                transfer_id: transfer_id.to_string(),
                remote_path: String::new(),
                transferred: 0,
                total: 0,
                done: true,
                error: Some(error.to_string()),
            },
        );
    }
}
