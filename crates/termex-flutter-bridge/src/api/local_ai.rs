/// Local AI (llama-server / Ollama) management exposed to Flutter via FRB.
///
/// Handles model download, server lifecycle, and health-check polling.
use flutter_rust_bridge::frb;
use std::path::PathBuf;

use crate::local_ai_state;

// ─── DTOs ────────────────────────────────────────────────────────────────────

/// Status of the local AI server process.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LocalAiStatus {
    /// Server process is not running.
    Stopped,
    /// Server is starting up.
    Starting,
    /// Server is running and responding to health checks.
    Running,
    /// Server crashed or failed to start.
    Error,
}

/// A downloadable model entry.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LocalModelDto {
    pub id: String,
    pub name: String,
    pub description: String,
    /// Size in bytes.
    pub size_bytes: u64,
    /// Formatted size string (e.g. "3.8 GB").
    pub size_label: String,
    pub quantization: String,
    /// Whether the model is already downloaded locally.
    pub is_downloaded: bool,
    /// Local file path, if downloaded.
    pub local_path: Option<String>,
}

/// Progress update emitted during model download.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ModelDownloadProgress {
    pub model_id: String,
    pub bytes_received: u64,
    pub total_bytes: u64,
    pub done: bool,
    pub error: Option<String>,
}

/// Health report from the running local AI server.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LocalAiHealth {
    pub status: LocalAiStatus,
    /// Currently loaded model ID, if any.
    pub loaded_model: Option<String>,
    /// Memory usage in MB.
    pub memory_mb: Option<u64>,
    /// Listening port.
    pub port: u16,
}

// ─── Server lifecycle ─────────────────────────────────────────────────────────

/// Start the local AI server with the given model.
/// Returns immediately; use [local_ai_health] to poll readiness.
///
/// `port` is accepted for API compatibility but ignored — the underlying
/// `LlamaServerState` auto-allocates a free port in the 15000–16000 range
/// to avoid conflicts with the legacy Tauri product. Callers can read the
/// actual port via [local_ai_health] after startup.
#[frb]
pub async fn local_ai_start(model_id: String, port: u16) -> Result<(), String> {
    let _ = port;

    // Resolve model file: `<data_dir>/models/<id>.gguf`
    let models_dir = termex_core::paths::data_dir().join("models");
    let model_path = models_dir.join(format!("{model_id}.gguf"));
    if !model_path.exists() {
        return Err(format!(
            "Model file not found: {}. Download it first.",
            model_path.display()
        ));
    }

    // Resolve llama-server binary (Homebrew / PATH / bundled).
    let default_binary = PathBuf::from("llama-server");
    let binary_path = termex_core::local_ai::binary_manager::ensure_binary_exists(&default_binary)
        .await
        .map(PathBuf::from)?;

    let mut server = local_ai_state::LLAMA_SERVER.write().await;
    server.start(binary_path, model_path).await.map(|_port| ())
}

/// Stop the local AI server process.
#[frb]
pub async fn local_ai_stop() -> Result<(), String> {
    let mut server = local_ai_state::LLAMA_SERVER.write().await;
    server.stop().await
}

/// Query the current health of the local AI server.
///
/// Uses the shared PID file written by termex-core to locate a running
/// llama-server instance (possibly started by the legacy Tauri product),
/// then probes its port for TCP readiness. Does not issue HTTP traffic —
/// the Dart layer can do that if richer telemetry is required.
#[frb]
pub async fn local_ai_health() -> LocalAiHealth {
    use termex_core::local_ai::{is_pid_alive, port_check::is_port_listening, read_pid_file};

    if let Some((pid, port)) = read_pid_file() {
        // pid alive AND port listening → Running
        if is_pid_alive(pid) && is_port_listening(port).await {
            return LocalAiHealth {
                status: LocalAiStatus::Running,
                loaded_model: None,
                memory_mb: None,
                port,
            };
        }
        // Stale pid file (process has exited). Behave as Stopped — a crashed
        // process that left the pid file behind shouldn't surface as a live
        // error to the user; the next start-up will reclaim the record.
    }
    LocalAiHealth {
        status: LocalAiStatus::Stopped,
        loaded_model: None,
        memory_mb: None,
        port: 0,
    }
}

// ─── Model management ─────────────────────────────────────────────────────────

/// Bundled catalogue of downloadable models, enriched with the current
/// local download state.
///
/// Catalogue data is static (the set of curated models we ship) and is
/// defined inline — there is no server-side catalogue to fetch. For each
/// entry we probe `app_data_dir/models/{id}.gguf` to mark it
/// `is_downloaded`.
#[frb]
pub fn local_ai_list_models() -> Vec<LocalModelDto> {
    let models_dir = termex_core::paths::data_dir().join("models");
    let catalogue = [
        (
            "llama3-8b-q4",
            "Llama 3 8B (Q4_K_M)",
            "Fast, general-purpose model. Good for command explanation.",
            4_661_190_656u64,
            "4.3 GB",
            "Q4_K_M",
        ),
        (
            "phi3-mini-q4",
            "Phi-3 Mini (Q4_K_M)",
            "Lightweight model for constrained hardware.",
            2_176_843_776,
            "2.0 GB",
            "Q4_K_M",
        ),
        (
            "qwen2-7b-q4",
            "Qwen2 7B (Q4_K_M)",
            "Strong CJK and code understanding.",
            4_294_967_296,
            "4.0 GB",
            "Q4_K_M",
        ),
    ];
    catalogue
        .into_iter()
        .map(|(id, name, desc, size, label, quant)| {
            let file = models_dir.join(format!("{id}.gguf"));
            let is_downloaded = file.exists();
            LocalModelDto {
                id: id.to_string(),
                name: name.to_string(),
                description: desc.to_string(),
                size_bytes: size,
                size_label: label.to_string(),
                quantization: quant.to_string(),
                is_downloaded,
                local_path: if is_downloaded {
                    Some(file.to_string_lossy().into_owned())
                } else {
                    None
                },
            }
        })
        .collect()
}

/// Start downloading a model and block until completion (or cancellation).
///
/// Runs HTTP range-aware download from the curated catalog URL into
/// `<data_dir>/models/<id>.gguf`. On failure the primary URL is retried once
/// against the configured mirror URL. Progress is not yet streamed through
/// FRB (that lands with the `StreamSink`-based emitter in a follow-up); the
/// Dart layer should call this and drive its own progress UI from an adjacent
/// polling timer or treat the call as atomic.
///
/// Use [local_ai_cancel_download] to abort an in-flight download.
#[frb]
pub async fn local_ai_download_model(model_id: String) -> Result<(), String> {
    let entry = local_ai_state::catalog_lookup(&model_id)
        .ok_or_else(|| format!("unknown model id: {model_id}"))?;

    let models_dir = termex_core::paths::data_dir().join("models");
    tokio::fs::create_dir_all(&models_dir)
        .await
        .map_err(|e| format!("failed to create models dir: {e}"))?;
    let destination = models_dir.join(entry.filename);

    // Register cancellation token, replacing any previous one for this id.
    let (tx, rx) = tokio::sync::oneshot::channel::<()>();
    local_ai_state::ACTIVE_DOWNLOADS.insert(model_id.clone(), tx);

    let primary = entry.url.to_string();
    let mirror = entry.mirror_url.map(|s| s.to_string());
    let sha = entry.sha256.to_string();
    let dest = destination.clone();

    let result =
        termex_core::local_ai::downloader::download_with_progress(&primary, &dest, &sha, rx, |_, _| {})
            .await;

    // If primary failed for non-cancellation reason, try mirror once.
    let final_result = match (result, mirror) {
        (Ok(()), _) => Ok(()),
        (Err(e), _) if e == "Download cancelled" => Err(e),
        (Err(primary_err), Some(mirror_url)) => {
            let (tx2, rx2) = tokio::sync::oneshot::channel::<()>();
            local_ai_state::ACTIVE_DOWNLOADS.insert(model_id.clone(), tx2);
            match termex_core::local_ai::downloader::download_with_progress(
                &mirror_url,
                &dest,
                &sha,
                rx2,
                |_, _| {},
            )
            .await
            {
                Ok(()) => Ok(()),
                Err(mirror_err) => Err(format!(
                    "primary failed ({primary_err}); mirror also failed: {mirror_err}"
                )),
            }
        }
        (Err(e), None) => Err(e),
    };

    local_ai_state::ACTIVE_DOWNLOADS.remove(&model_id);
    final_result
}

/// Delete a downloaded model from disk.
///
/// Looks up the canonical model filename in `app_data_dir/models/` and
/// unlinks it. Missing files are treated as successful (idempotent delete).
#[frb]
pub async fn local_ai_delete_model(model_id: String) -> Result<(), String> {
    let models_dir = termex_core::paths::data_dir().join("models");
    let filename = format!("{model_id}.gguf");
    let path = models_dir.join(&filename);
    if path.exists() {
        tokio::fs::remove_file(&path)
            .await
            .map_err(|e| format!("failed to delete {}: {e}", path.display()))?;
    }
    Ok(())
}

/// Cancel an in-progress model download.
#[frb]
pub fn local_ai_cancel_download(model_id: String) {
    if let Some((_, tx)) = local_ai_state::ACTIVE_DOWNLOADS.remove(&model_id) {
        let _ = tx.send(());
    }
}

/// Return the base URL for the local AI server, auto-detected from the
/// PID file written by termex-core when the server is running. Falls back
/// to the conventional `127.0.0.1:8080` when no server is active.
#[frb]
pub fn local_ai_base_url() -> String {
    if let Some((_pid, port)) = termex_core::local_ai::read_pid_file() {
        return format!("http://127.0.0.1:{port}");
    }
    "http://127.0.0.1:8080".to_string()
}

/// Return available disk space in bytes at the app data directory.
/// Used to warn the user before starting a large model download.
///
/// If the platform-specific check in `termex_core::local_ai::storage` is
/// unavailable (the current placeholder returns `None`), we report a
/// conservative 20 GB so the UI can continue without a hard-fail. A future
/// tech-debt item will wire `fs2::available_space` across platforms.
#[frb]
pub fn local_ai_check_disk_space() -> Result<u64, String> {
    let dir = termex_core::paths::data_dir();
    Ok(termex_core::local_ai::storage::get_available_space(&dir)
        .unwrap_or(20 * 1024 * 1024 * 1024))
}

/// Cancel the pending or in-progress auto-start of the local AI server.
///
/// Called when the user disables the "auto-start on launch" setting while
/// Termex is starting up. Sets an atomic flag that the auto-start coroutine
/// (owned by the Flutter layer) must check before each step.
#[frb]
pub fn local_ai_cancel_auto_start() {
    local_ai_state::AUTO_START_CANCELLED.store(true, std::sync::atomic::Ordering::SeqCst);
}

/// Returns true when the auto-start sequence should abort.
/// The Flutter auto-start coroutine polls this before each expensive step.
#[frb]
pub fn local_ai_auto_start_is_cancelled() -> bool {
    local_ai_state::AUTO_START_CANCELLED.load(std::sync::atomic::Ordering::SeqCst)
}

/// Reset the auto-start cancellation flag; call at the start of each launch
/// sequence before polling [local_ai_auto_start_is_cancelled].
#[frb]
pub fn local_ai_auto_start_reset() {
    local_ai_state::AUTO_START_CANCELLED.store(false, std::sync::atomic::Ordering::SeqCst);
}
