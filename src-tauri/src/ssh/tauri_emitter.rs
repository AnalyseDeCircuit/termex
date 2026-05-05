use tauri::{AppHandle, Emitter, Manager};
use termex_core::ssh::event_emitter::SshEventEmitter;

/// Tauri implementation of SshEventEmitter.
/// Emits events via tauri::AppHandle and hooks into session recording.
pub struct TauriSshEmitter(pub AppHandle);

#[async_trait::async_trait]
impl SshEventEmitter for TauriSshEmitter {
    fn emit_stdout(&self, session_id: &str, data: Vec<u8>) {
        let event = format!("ssh://data/{session_id}");
        let _ = self.0.emit(&event, data);
    }

    fn emit_exit_status(&self, session_id: &str, exit_code: u32) {
        let event = format!("ssh://status/{session_id}");
        let _ = self.0.emit(&event, serde_json::json!({
            "status": "exited",
            "message": format!("exit code: {exit_code}"),
        }));
    }

    fn emit_disconnected(&self, session_id: &str) {
        let event = format!("ssh://status/{session_id}");
        let _ = self.0.emit(&event, serde_json::json!({
            "status": "disconnected",
            "message": "connection closed",
        }));
    }

    fn emit_port_forward_event(&self, event: &str, payload: &str) {
        let _ = self.0.emit(event, payload);
    }

    async fn on_data_side_effect(&self, session_id: &str, data: &[u8]) {
        let Some(state) = self.0.try_state::<crate::state::AppState>() else {
            return;
        };
        let text = String::from_utf8_lossy(data);
        let within_limit = state.recorder.record_output(session_id, &text).await;
        if !within_limit {
            if let Ok(_) = state.recorder.stop(session_id).await {
                let _ = crate::commands::recording::finalize_recording_for_session(
                    state.inner(),
                    session_id,
                )
                .await;
                let _ = self.0.emit(
                    &format!("recording://auto-stopped/{session_id}"),
                    serde_json::json!({ "reason": "size_limit" }),
                );
            }
        }
    }
}
