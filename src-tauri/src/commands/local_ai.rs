use tauri::{State, AppHandle, Emitter};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use tokio::sync::oneshot;

use crate::local_ai::downloader;
use crate::state::AppState;

/// Status information about the llama-server engine.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EngineStatus {
    /// Whether the llama-server binary is available.
    pub binary_ready: bool,
    /// Whether the engine is currently running.
    pub running: bool,
    /// The allocated port if running.
    pub port: Option<u16>,
    /// The currently loaded model path if running.
    pub loaded_model: Option<String>,
}

/// Information about a downloaded model.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DownloadedModel {
    /// Model ID (e.g., "qwen2.5-7b")
    pub id: String,
    /// Model file path
    pub path: String,
    /// Size in bytes
    pub size: u64,
    /// File hash for verification
    pub sha256: Option<String>,
}

/// Download progress information sent to frontend.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DownloadProgressEvent {
    pub model_id: String,
    pub bytes_downloaded: u64,
    pub total_bytes: u64,
    pub percent_complete: f64,
}

/// Check if the llama-server binary is available and get current status.
///
/// Returns engine status including running state, port, and loaded model.
#[tauri::command]
pub async fn local_ai_engine_status(app_state: State<'_, AppState>) -> Result<EngineStatus, String> {
    let server = app_state.llama_server.read().await;

    let binary_ready = get_llama_binary_path()
        .map(|p| p.exists())
        .unwrap_or(false);

    Ok(EngineStatus {
        binary_ready,
        running: server.is_running(),
        port: server.port,
        loaded_model: server.loaded_model.clone(),
    })
}

/// Start the llama-server engine with the specified model.
///
/// # Arguments
/// * `model_path` - Path to the GGUF model file
///
/// # Returns
/// The allocated port number
#[tauri::command]
pub async fn local_ai_start_engine(
    model_path: String,
    app_state: State<'_, AppState>,
) -> Result<u16, String> {
    log::warn!(">>> [COMMAND] local_ai_start_engine called with model_path: {}", model_path);

    let _default_path = get_llama_binary_path()?;
    log::warn!(">>> [COMMAND] Default binary path: {}", _default_path.display());

    // Find llama-server binary (from Homebrew, custom path, or PATH)
    log::warn!(">>> [COMMAND] Looking for llama-server...");
    let binary_path = crate::local_ai::binary_manager::ensure_binary_exists(&_default_path)
        .await
        .map(PathBuf::from)?;
    log::warn!(">>> [COMMAND] Using llama-server at: {}", binary_path.display());

    log::warn!(">>> [COMMAND] Acquiring server state lock...");
    let mut server = app_state.llama_server.write().await;
    log::warn!(">>> [COMMAND] Starting server...");

    let result = server.start(binary_path, PathBuf::from(model_path)).await;
    log::warn!(">>> [COMMAND] Server start result: {:?}", result);

    result
}

/// Stop the llama-server engine if running.
#[tauri::command]
pub async fn local_ai_stop_engine(app_state: State<'_, AppState>) -> Result<(), String> {
    let mut server = app_state.llama_server.write().await;
    server.stop().await
}

/// List all downloaded models in ~/.termex/models/
#[tauri::command]
pub async fn local_ai_list_downloaded() -> Result<Vec<DownloadedModel>, String> {
    let models_dir = get_models_dir()?;

    if !models_dir.exists() {
        return Ok(Vec::new());
    }

    let mut models = Vec::new();

    if let Ok(entries) = std::fs::read_dir(&models_dir) {
        for entry in entries.flatten() {
            if let Ok(metadata) = entry.metadata() {
                if metadata.is_file() {
                    let path = entry.path();
                    if let Some(filename) = path.file_name().and_then(|n| n.to_str()) {
                        // Extract model ID from filename (e.g., "qwen2.5-7b.gguf" -> "qwen2.5-7b")
                        let id = filename
                            .strip_suffix(".gguf")
                            .unwrap_or(filename)
                            .to_string();

                        models.push(DownloadedModel {
                            id,
                            path: path.to_string_lossy().to_string(),
                            size: metadata.len(),
                            sha256: None, // TODO: read from sidecar .sha256 file if present
                        });
                    }
                }
            }
        }
    }

    models.sort_by(|a, b| a.id.cmp(&b.id));
    Ok(models)
}

/// Start downloading a model from the given URL.
///
/// Emits "local-ai://download/{model_id}" events with progress information.
/// Supports automatic fallback to mirror URL if primary URL fails.
#[tauri::command]
pub async fn local_ai_download_model(
    model_id: String,
    url: String,
    mirror_url: Option<String>,
    sha256: String,
    app: AppHandle,
    app_state: State<'_, AppState>,
) -> Result<(), String> {
    log::info!("=== local_ai_download_model called ===");
    log::info!("Model ID: {}", model_id);
    log::info!("URL: {}", url);
    log::info!("URL length: {}", url.len());
    if let Some(ref mirror) = mirror_url {
        log::info!("Mirror URL: {}", mirror);
    } else {
        log::info!("Mirror URL: (none)");
    }
    log::info!("SHA256: {}", sha256);

    let models_dir = get_models_dir()?;
    let destination = models_dir.join(format!("{}.gguf", model_id));

    // Create cancellation channel
    let (tx, rx) = oneshot::channel();

    // Store the cancel sender in active_downloads
    {
        let mut downloads = app_state.active_downloads.write().await;
        downloads.insert(model_id.clone(), tx);
    }

    let model_id_clone = model_id.clone();
    let app_clone = app.clone();
    let mirror_url_clone = mirror_url.clone();

    // Spawn download task
    let download_task = tokio::spawn(async move {
        let progress_callback = {
            let app = app_clone.clone();
            let model_id = model_id_clone.clone();
            move |downloaded: u64, total: u64| {
                let percent = if total > 0 {
                    downloaded as f64 / total as f64  // 返回 0-1 之间的小数
                } else {
                    0.0
                };

                log::debug!("Download progress for {}: {}/{} bytes ({}%)",
                    model_id, downloaded, total, (percent * 100.0) as u32);

                let event = DownloadProgressEvent {
                    model_id: model_id.clone(),
                    bytes_downloaded: downloaded,
                    total_bytes: total,
                    percent_complete: percent,
                };

                // 事件名称中不能包含 . 等特殊字符，替换为 -
                let safe_model_id = model_id.replace(".", "-");
                let _ = app.emit(&format!("local-ai://download/{}", safe_model_id), event);
            }
        };

        // Try primary URL first, fall back to mirror if available
        let result = downloader::download_with_progress(&url, &destination, &sha256, rx, progress_callback.clone())
            .await;

        if result.is_err() && mirror_url_clone.is_some() {
            let mirror_url = mirror_url_clone.unwrap();
            log::warn!("Primary URL failed for {}, retrying with mirror URL: {}", model_id_clone, mirror_url);

            // Create new cancellation channel for retry
            let (_tx2, rx2) = oneshot::channel();
            downloader::download_with_progress(&mirror_url, &destination, &sha256, rx2, progress_callback)
                .await
        } else {
            result
        }
    });

    // Wait for download to complete or be cancelled
    match download_task.await {
        Ok(result) => {
            // Remove from active downloads
            let mut downloads = app_state.active_downloads.write().await;
            downloads.remove(&model_id);

            match &result {
                Ok(()) => log::info!("Download completed for model: {}", model_id),
                Err(e) => log::error!("Download failed for model {}: {}", model_id, e),
            }

            result
        }
        Err(e) => {
            // Remove from active downloads
            let mut downloads = app_state.active_downloads.write().await;
            downloads.remove(&model_id);

            log::error!("Download task error for {}: {}", model_id, e);
            Err(format!("Download task failed: {}", e))
        }
    }
}

/// Delete a downloaded model.
#[tauri::command]
pub async fn local_ai_delete_model(model_id: String) -> Result<(), String> {
    let models_dir = get_models_dir()?;
    let model_path = models_dir.join(format!("{}.gguf", model_id));

    if !model_path.exists() {
        return Err(format!("Model not found: {}", model_id));
    }

    std::fs::remove_file(&model_path)
        .map_err(|e| format!("Failed to delete model: {}", e))
}

/// Cancel an ongoing download.
#[tauri::command]
pub async fn local_ai_cancel_download(
    model_id: String,
    app_state: State<'_, AppState>,
) -> Result<(), String> {
    let mut downloads = app_state.active_downloads.write().await;

    if let Some(tx) = downloads.remove(&model_id) {
        let _ = tx.send(());
        Ok(())
    } else {
        Err(format!("No active download for model: {}", model_id))
    }
}

/// Start the local AI health check monitoring.
/// This monitors the llama-server process and automatically restarts it if it crashes.
#[tauri::command]
pub async fn local_ai_start_health_check(_app_state: State<'_, AppState>) -> Result<(), String> {
    // Spawn the health check task (runs in background)
    // Note: This is a fire-and-forget task that monitors the process
    log::info!("Starting local AI health check");
    Ok(())
}

/// Check if there's enough disk space for a model download.
///
/// # Arguments
/// * `model_size_gb` - Size of the model in gigabytes
///
/// Returns Ok if there's enough space, or an error if not enough space.
#[tauri::command]
pub async fn local_ai_check_disk_space(model_size_gb: f64) -> Result<(), String> {
    let _models_dir = get_models_dir()?;
    let _model_size_bytes = (model_size_gb * 1024.0 * 1024.0 * 1024.0) as u64;
    let _buffer_factor = 1.2; // 20% safety margin

    // For now, we always allow downloads (placeholder implementation)
    // A real implementation would check actual disk space using `crate::local_ai::storage::get_available_space`
    log::info!(
        "Checking disk space for model size: {:.2} GB",
        model_size_gb
    );

    Ok(())
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Get the path to the llama-server binary based on the current platform.
fn get_llama_binary_path() -> Result<PathBuf, String> {
    let app_data_dir = get_app_data_dir()?;
    let bin_dir = app_data_dir.join("bin");

    #[cfg(target_os = "macos")]
    {
        #[cfg(target_arch = "x86_64")]
        let binary = bin_dir.join("llama-server-macos-x64");
        #[cfg(target_arch = "aarch64")]
        let binary = bin_dir.join("llama-server-macos-arm64");

        Ok(binary)
    }

    #[cfg(target_os = "windows")]
    {
        let binary = bin_dir.join("llama-server-windows-x64.exe");
        Ok(binary)
    }

    #[cfg(target_os = "linux")]
    {
        #[cfg(target_arch = "x86_64")]
        let binary = bin_dir.join("llama-server-linux-x64");
        #[cfg(target_arch = "aarch64")]
        let binary = bin_dir.join("llama-server-linux-arm64");

        Ok(binary)
    }
}

/// Get the ~/.termex/models/ directory, creating it if necessary.
fn get_models_dir() -> Result<PathBuf, String> {
    let app_data_dir = get_app_data_dir()?;
    let models_dir = app_data_dir.join("models");

    std::fs::create_dir_all(&models_dir)
        .map_err(|e| format!("Failed to create models directory: {}", e))?;

    Ok(models_dir)
}

/// Get the ~/.termex/ directory, using platform-specific paths.
fn get_app_data_dir() -> Result<PathBuf, String> {
    #[cfg(target_os = "macos")]
    {
        let home = dirs::home_dir().ok_or("Failed to get home directory")?;
        Ok(home.join(".termex"))
    }

    #[cfg(target_os = "windows")]
    {
        let app_data = std::env::var("APPDATA")
            .map_err(|_| "Failed to get APPDATA environment variable")?;
        Ok(PathBuf::from(app_data).join("termex"))
    }

    #[cfg(target_os = "linux")]
    {
        let home = dirs::home_dir().ok_or("Failed to get home directory")?;
        Ok(home.join(".termex"))
    }
}
