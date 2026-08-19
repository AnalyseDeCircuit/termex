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
    /// Size tier: micro / small / medium / large.
    pub tier: String,
    /// RAM the model needs to run, in GB. Shown by the Tauri build's list and
    /// dropped in the port.
    pub min_ram_gb: u32,
    /// Context window the model was built for.
    pub context_length: u32,
    /// Marks the entry the catalogue suggests first.
    pub recommended: bool,
    /// True when the file is on disk but no catalogue entry describes it —
    /// a model an older build downloaded, or one dropped in by hand. It can
    /// be run and deleted, but not re-downloaded.
    pub is_adopted: bool,
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

    // Resolve the model wherever it actually sits — a file the Tauri build
    // downloaded lives in a different directory from this build's default.
    let model_path = local_ai_state::find_model_file(&format!("{model_id}.gguf"))
        .unwrap_or_else(|| local_ai_state::model_download_dir()
            .join(format!("{model_id}.gguf")));
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
    let on_disk = local_ai_state::scan_downloaded_models();

    let mut out: Vec<LocalModelDto> = local_ai_state::MODEL_CATALOG
        .iter()
        .map(|e| {
            let found = on_disk.iter().find(|(id, _, _)| id == e.id);
            LocalModelDto {
                id: e.id.to_string(),
                name: e.display_name.to_string(),
                description: e.description.to_string(),
                size_bytes: e.size_bytes,
                size_label: e.size_label.to_string(),
                quantization: e.quantization.to_string(),
                is_downloaded: found.is_some(),
                local_path: found.map(|(_, p, _)| p.to_string_lossy().into_owned()),
                tier: e.tier.to_string(),
                min_ram_gb: e.min_ram_gb,
                context_length: e.context_length,
                recommended: e.recommended,
                is_adopted: false,
            }
        })
        .collect();

    // Files present on disk that no catalogue entry claims. The Tauri build
    // listed what was actually there, so a model downloaded under an id this
    // build no longer ships still has to appear — and be runnable — instead
    // of prompting a re-download of something the user already has.
    for (id, path, size) in on_disk {
        if local_ai_state::catalog_lookup(&id).is_some() {
            continue;
        }
        out.push(LocalModelDto {
            id: id.clone(),
            name: id,
            description: String::new(),
            size_bytes: size,
            size_label: format_size(size),
            quantization: String::new(),
            is_downloaded: true,
            local_path: Some(path.to_string_lossy().into_owned()),
            tier: String::new(),
            min_ram_gb: 0,
            context_length: 0,
            recommended: false,
            is_adopted: true,
        });
    }
    out
}

/// Human-readable byte count for models discovered on disk, which carry no
/// catalogue label of their own.
fn format_size(bytes: u64) -> String {
    const GB: f64 = 1024.0 * 1024.0 * 1024.0;
    let gb = bytes as f64 / GB;
    if gb < 1.0 {
        format!("{:.0} MB", bytes as f64 / (1024.0 * 1024.0))
    } else {
        format!("{gb:.1} GB")
    }
}

/// Start downloading a model and block until completion (or cancellation).
///
/// Runs HTTP range-aware download from the curated catalog URL into
/// `<data_dir>/models/<id>.gguf`. On failure the primary URL is retried once
/// against the configured mirror URL.
///
/// **Progress reporting (v0.77.0)**: the downloader's per-chunk callback
/// writes `(downloaded, total)` bytes into [`local_ai_state::DOWNLOAD_PROGRESS`].
/// Dart polls [`local_ai_download_progress`] every ~250 ms to drive the
/// progress bar; the entry is removed when the download completes or is
/// cancelled, so an absent entry signals "no active download for this id".
///
/// Use [local_ai_cancel_download] to abort an in-flight download.
#[frb]
pub async fn local_ai_download_model(model_id: String) -> Result<(), String> {
    let entry = local_ai_state::catalog_lookup(&model_id)
        .ok_or_else(|| format!("unknown model id: {model_id}"))?;

    let models_dir = local_ai_state::model_download_dir();
    tokio::fs::create_dir_all(&models_dir)
        .await
        .map_err(|e| format!("failed to create models dir: {e}"))?;
    let destination = models_dir.join(entry.filename);

    // Register cancellation token, replacing any previous one for this id.
    let (tx, rx) = tokio::sync::oneshot::channel::<()>();
    local_ai_state::ACTIVE_DOWNLOADS.insert(model_id.clone(), tx);
    // Seed the progress entry so polling returns "0 of 0" immediately on
    // download start (rather than `None`, which the Dart layer reads as
    // "not running").
    local_ai_state::DOWNLOAD_PROGRESS.insert(model_id.clone(), (0, 0));

    let primary = entry.url.to_string();
    let mirror = entry.mirror_url.map(|s| s.to_string());
    let sha = entry.sha256.to_string();
    let dest = destination.clone();

    let progress_id = model_id.clone();
    let progress_cb = move |downloaded: u64, total: u64| {
        local_ai_state::DOWNLOAD_PROGRESS
            .insert(progress_id.clone(), (downloaded, total));
    };

    let result = termex_core::local_ai::downloader::download_with_progress(
        &primary, &dest, &sha, rx, progress_cb,
    )
    .await;

    // If primary failed for non-cancellation reason, try mirror once.
    let final_result = match (result, mirror) {
        (Ok(()), _) => Ok(()),
        (Err(e), _) if e == "Download cancelled" => Err(e),
        (Err(primary_err), Some(mirror_url)) => {
            let (tx2, rx2) = tokio::sync::oneshot::channel::<()>();
            local_ai_state::ACTIVE_DOWNLOADS.insert(model_id.clone(), tx2);
            let mirror_id = model_id.clone();
            let mirror_cb = move |downloaded: u64, total: u64| {
                local_ai_state::DOWNLOAD_PROGRESS
                    .insert(mirror_id.clone(), (downloaded, total));
            };
            match termex_core::local_ai::downloader::download_with_progress(
                &mirror_url, &dest, &sha, rx2, mirror_cb,
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
    // Keep the final progress row briefly so the UI can paint "100%"
    // on the same poll cycle, then clear it on next call.
    local_ai_state::DOWNLOAD_PROGRESS.remove(&model_id);
    final_result
}

/// DTO returned by [`local_ai_download_progress`]: bytes downloaded so
/// far + total content length (zero when the server didn't send
/// `Content-Length`, meaning the UI should show indeterminate spinner).
#[frb]
#[derive(Debug, Clone)]
pub struct LocalAiDownloadProgress {
    pub downloaded: u64,
    pub total: u64,
}

/// Polls the current download progress for `model_id`. Returns `None`
/// when no download is active for that model. The Dart UI calls this
/// on a 250 ms timer while the download future is pending.
#[frb]
pub fn local_ai_download_progress(
    model_id: String,
) -> Option<LocalAiDownloadProgress> {
    local_ai_state::DOWNLOAD_PROGRESS
        .get(&model_id)
        .map(|e| LocalAiDownloadProgress {
            downloaded: e.value().0,
            total: e.value().1,
        })
}

/// Delete a downloaded model from disk.
///
/// v0.79.58: resolve the on-disk filename through the catalog (was
/// `format!("{id}.gguf")` — only correct by coincidence for the current
/// catalog). Also unlinks the matching `.tmp` partial when present so a
/// cancelled-then-deleted model doesn't leave half-downloaded bytes
/// occupying user disk space.
///
/// Missing files are treated as successful (idempotent delete).
#[frb]
pub async fn local_ai_delete_model(model_id: String) -> Result<(), String> {
    // Prefer the catalog filename — defensive against future catalog
    // entries whose filename doesn't equal `{id}.gguf`.
    let filename = local_ai_state::catalog_lookup(&model_id)
        .map(|e| e.filename.to_string())
        .unwrap_or_else(|| format!("{model_id}.gguf"));

    // Delete it where it actually is, which may be the directory the Tauri
    // build wrote to rather than this build's own.
    let path = local_ai_state::find_model_file(&filename)
        .unwrap_or_else(|| local_ai_state::model_download_dir().join(&filename));
    if path.exists() {
        tokio::fs::remove_file(&path)
            .await
            .map_err(|e| format!("failed to delete {}: {e}", path.display()))?;
    }

    // Also remove the partial-download companion if present. Best-effort:
    // a failure here shouldn't fail the user-facing delete.
    let tmp_path = path.with_extension("tmp");
    if tmp_path.exists() {
        let _ = tokio::fs::remove_file(&tmp_path).await;
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
