pub mod binary_manager;
pub mod downloader;
pub mod health_check;
pub mod storage;

use std::path::{Path, PathBuf};
use std::process::Stdio;

/// 规范化路径以便比较（处理符号链接、.. 等）
fn normalize_path(path: &Path) -> String {
    // 尝试规范化为绝对路径，如果失败就用原始路径
    match std::fs::canonicalize(path) {
        Ok(canonical) => canonical.to_string_lossy().to_string(),
        Err(_) => path.to_string_lossy().to_string(),
    }
}

/// Represents the current state of the llama-server process.
#[derive(Debug, Clone)]
pub struct LlamaServerState {
    /// The llama-server subprocess, if running.
    pub process_id: Option<u32>,
    /// The allocated port number (15000-16000 range).
    pub port: Option<u16>,
    /// The currently loaded model path.
    pub loaded_model: Option<String>,
    /// true = this app instance started the process; false = reusing another window's instance.
    pub is_owner: bool,
}

impl Default for LlamaServerState {
    fn default() -> Self {
        Self::new()
    }
}

impl Drop for LlamaServerState {
    fn drop(&mut self) {
        // Only kill the process if this instance started it
        if !self.is_owner {
            return;
        }
        remove_pid_file();
        if let Some(pid) = self.process_id {
            eprintln!(">>> [MOD] Cleaning up llama-server process (PID: {}) on app shutdown", pid);
            #[cfg(target_os = "windows")]
            {
                let _ = std::process::Command::new("taskkill")
                    .arg("/PID")
                    .arg(pid.to_string())
                    .arg("/F")
                    .output();
            }

            #[cfg(not(target_os = "windows"))]
            {
                let _ = std::process::Command::new("kill")
                    .arg("-9")
                    .arg(pid.to_string())
                    .output();
            }
        }
    }
}

impl LlamaServerState {
    /// Creates a new, uninitialized LlamaServerState.
    pub fn new() -> Self {
        Self {
            process_id: None,
            port: None,
            loaded_model: None,
            is_owner: false,
        }
    }

    /// Starts the llama-server process with the given model.
    ///
    /// # Arguments
    /// * `binary_path` - Path to the llama-server binary
    /// * `model_path` - Path to the GGUF model file
    ///
    /// # Returns
    /// The allocated port number if successful, or an error message.
    pub async fn start(
        &mut self,
        binary_path: PathBuf,
        model_path: PathBuf,
    ) -> Result<u16, String> {
        eprintln!(">>> [MOD] start() called with model: {}", model_path.display());

        // 规范化模型路径以便比较
        let normalized_model = normalize_path(&model_path);
        eprintln!(">>> [MOD] Model path normalized:");
        eprintln!(">>> [MOD]   Original: {}", model_path.display());
        eprintln!(">>> [MOD]   Normalized: {}", normalized_model);

        // If same model is already loaded and running, return the existing port
        if let Some(loaded) = &self.loaded_model {
            eprintln!(">>> [MOD] Checking if model already loaded:");
            eprintln!(">>> [MOD]   Loaded model: {}", loaded);
            eprintln!(">>> [MOD]   Current model: {}", normalized_model);
            eprintln!(">>> [MOD]   Models match: {}", loaded == &normalized_model);
            eprintln!(">>> [MOD]   PID: {:?}", self.process_id);
            let is_running = self.is_running();
            eprintln!(">>> [MOD]   Process running: {}", is_running);

            if loaded == &normalized_model && is_running {
                eprintln!(">>> [MOD] Same model already running on port {:?}", self.port);
                log::info!("Model already loaded: {}", loaded);
                return self.port.ok_or_else(|| "Port not set but process is running".to_string());
            } else {
                eprintln!(">>> [MOD] Need to restart: model mismatch or process not running");
            }
        } else {
            eprintln!(">>> [MOD] No previous model loaded");
        }

        // Different model or process not running, stop the old one
        if self.process_id.is_some() {
            eprintln!(">>> [MOD] Stopping previous process before starting new one");
            let _ = self.stop().await;
            // Give it a moment to fully terminate
            tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
        }

        // Kill any orphaned llama-server processes from previous app runs
        // (e.g., after dev hot-reload where Drop didn't fire properly)
        kill_orphaned_llama_servers();

        // Verify binary and model exist
        if !binary_path.exists() {
            return Err(format!("llama-server binary not found: {}", binary_path.display()));
        }
        if !model_path.exists() {
            return Err(format!("Model file not found: {}", model_path.display()));
        }

        // Ensure binary exists and get its path
        eprintln!(">>> [MOD] Locating llama-server binary...");
        let actual_binary_path = crate::local_ai::binary_manager::ensure_binary_exists(&binary_path)
            .await
            .map(PathBuf::from)?;

        // Find available port (15000-16000 range - less common, less prone to conflicts)
        let port = find_available_port(15000, 16000)
            .map_err(|_| "No available port in range 15000-16000".to_string())?;

        // Start the process with inherited stdio for direct output
        eprintln!(">>> [MOD] Spawning llama-server: {:?}", &actual_binary_path);
        eprintln!(">>> [MOD] Model: {:?}", &model_path);
        eprintln!(">>> [MOD] Port: {}", port);

        let child = std::process::Command::new(&actual_binary_path)
            .arg("--model")
            .arg(&model_path)
            .arg("--port")
            .arg(port.to_string())
            .arg("--n-gpu-layers")
            .arg("99")
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .spawn()
            .map_err(|e| {
                eprintln!(">>> [MOD] Failed to spawn process: {}", e);
                format!("Failed to spawn llama-server: {}", e)
            })?;

        let pid = child.id();
        eprintln!(">>> [MOD] Process spawned with PID: {}", pid);

        // Update state with the PID and normalized model path
        self.process_id = Some(pid);
        self.port = Some(port);
        self.loaded_model = Some(normalized_model.clone());
        self.is_owner = true;
        write_pid_file(pid, port);

        // Detach the child process (let it run in background)
        // We'll track it via PID only
        drop(child);

        // Give the process a tiny moment to crash if it's going to
        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

        // Check if process is still alive before waiting for port
        if !self.is_running() {
            eprintln!(">>> [MOD] Process died immediately after spawn! PID {} is not running", pid);
            return Err("llama-server process died immediately after startup. Check the binary file and dependencies.".to_string());
        }

        eprintln!(">>> [MOD] Process is alive, waiting for port {} to listen (this may take up to 120 seconds for model loading)...", port);
        log::info!("Process alive, waiting for llama-server (PID: {}) to start listening on port {}...", pid, port);

        match crate::local_ai::health_check::wait_for_port(port, 120).await {
            Ok(()) => {
                eprintln!(">>> [MOD] llama-server successfully started and listening on port {}", port);
                log::info!("llama-server successfully started and listening on port {}", port);
                Ok(port)
            }
            Err(e) => {
                eprintln!(">>> [MOD] Failed to start llama-server on port {}: {}", port, e);
                log::error!("Failed to start llama-server on port {}: {}", port, e);

                // Check if process is still running
                let is_alive = self.is_running();
                eprintln!(">>> [MOD] Process alive after timeout: {}", is_alive);

                // Try to stop the process
                let _ = self.stop().await;
                Err(format!("llama-server failed to start: {}", e))
            }
        }
    }

    /// Stops the llama-server process if running.
    pub async fn stop(&mut self) -> Result<(), String> {
        if let Some(pid) = self.process_id {
            // Try to kill the process
            #[cfg(target_os = "windows")]
            {
                std::process::Command::new("taskkill")
                    .arg("/PID")
                    .arg(pid.to_string())
                    .arg("/F")
                    .output()
                    .map_err(|e| format!("Failed to kill process: {}", e))?;
            }

            #[cfg(not(target_os = "windows"))]
            {
                std::process::Command::new("kill")
                    .arg("-9")
                    .arg(pid.to_string())
                    .output()
                    .map_err(|e| format!("Failed to kill process: {}", e))?;
            }

            // Small delay to ensure process is killed
            tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
        }

        self.process_id = None;
        self.port = None;
        self.loaded_model = None;
        if self.is_owner {
            remove_pid_file();
        }
        self.is_owner = false;

        Ok(())
    }

    /// Checks if the process is still running.
    pub fn is_running(&self) -> bool {
        if let Some(pid) = self.process_id {
            let running = check_process_running(pid);
            eprintln!(">>> [MOD] check_process_running({}) = {}", pid, running);
            running
        } else {
            eprintln!(">>> [MOD] No PID stored, process not running");
            false
        }
    }
}

/// Attempts to recover state by discovering a running llama-server on known ports.
/// Called on app startup or when state is lost after dev hot-reload.
pub async fn try_recover_llama_state(state: &LlamaServerState) -> Option<u16> {
    // If we already know the port, nothing to recover
    if state.port.is_some() {
        return state.port;
    }

    let client = match reqwest::Client::builder()
        .timeout(std::time::Duration::from_millis(300))
        .build()
    {
        Ok(c) => c,
        Err(_) => return None,
    };

    // Scan the port range we use for llama-server
    for port in 15000..=15020 {
        let url = format!("http://localhost:{}/health", port);
        if let Ok(resp) = client.get(&url).send().await {
            if resp.status().is_success() {
                log::info!("[local_ai] Discovered running llama-server on port {}", port);
                return Some(port);
            }
        }
    }
    None
}

/// Kills any orphaned llama-server processes left over from previous app sessions.
/// This handles the case where the app crashed, dev hot-reloaded, or Drop didn't fire.
#[cfg(not(target_os = "windows"))]
fn kill_orphaned_llama_servers() {
    use std::process::Command;
    // Find llama-server processes and kill them
    if let Ok(output) = Command::new("pgrep").arg("-f").arg("llama-server.*--port 15").output() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        for line in stdout.lines() {
            if let Ok(pid) = line.trim().parse::<u32>() {
                eprintln!(">>> [MOD] Killing orphaned llama-server PID: {}", pid);
                let _ = Command::new("kill").arg("-9").arg(pid.to_string()).output();
            }
        }
    }
    // Brief pause to let ports free up
    std::thread::sleep(std::time::Duration::from_millis(300));
}

#[cfg(target_os = "windows")]
fn kill_orphaned_llama_servers() {
    use std::process::Command;
    let _ = Command::new("taskkill")
        .args(["/F", "/IM", "llama-server*.exe"])
        .output();
    std::thread::sleep(std::time::Duration::from_millis(300));
}

/// Finds an available TCP port in the given range.
fn find_available_port(start: u16, end: u16) -> Result<u16, String> {
    use std::net::TcpListener;

    for port in start..=end {
        if let Ok(listener) = TcpListener::bind(("127.0.0.1", port)) {
            drop(listener);
            return Ok(port);
        }
    }

    Err("No available port found".to_string())
}

/// Checks if a process with the given PID is still running.
#[cfg(target_os = "macos")]
fn check_process_running(pid: u32) -> bool {
    match std::process::Command::new("kill")
        .arg("-0")
        .arg(pid.to_string())
        .output()
    {
        Ok(output) => {
            let running = output.status.success();
            eprintln!(">>> [CHECK] kill -0 {} = {}", pid, running);
            if !running {
                eprintln!(">>> [CHECK] kill stderr: {}", String::from_utf8_lossy(&output.stderr));
            }
            running
        }
        Err(e) => {
            eprintln!(">>> [CHECK] kill -0 {} failed: {}", pid, e);
            false
        }
    }
}

#[cfg(target_os = "linux")]
fn check_process_running(pid: u32) -> bool {
    match std::process::Command::new("kill")
        .arg("-0")
        .arg(pid.to_string())
        .output()
    {
        Ok(output) => {
            let running = output.status.success();
            eprintln!(">>> [CHECK] kill -0 {} = {}", pid, running);
            if !running {
                eprintln!(">>> [CHECK] kill stderr: {}", String::from_utf8_lossy(&output.stderr));
            }
            running
        }
        Err(e) => {
            eprintln!(">>> [CHECK] kill -0 {} failed: {}", pid, e);
            false
        }
    }
}

#[cfg(target_os = "windows")]
fn check_process_running(pid: u32) -> bool {
    std::process::Command::new("tasklist")
        .arg("/FI")
        .arg(format!("PID eq {}", pid))
        .output()
        .map(|output| String::from_utf8_lossy(&output.stdout).contains(&pid.to_string()))
        .unwrap_or(false)
}

// ── PID file management ──

const PID_FILE_NAME: &str = ".llama-server.pid";

/// Writes PID + port to a file so other windows can detect the running instance.
fn write_pid_file(pid: u32, port: u16) {
    let path = crate::paths::data_dir().join(PID_FILE_NAME);
    let _ = std::fs::write(&path, format!("{pid}\n{port}"));
}

/// Reads PID + port from the PID file.
pub fn read_pid_file() -> Option<(u32, u16)> {
    let path = crate::paths::data_dir().join(PID_FILE_NAME);
    let content = std::fs::read_to_string(&path).ok()?;
    let mut lines = content.lines();
    let pid: u32 = lines.next()?.parse().ok()?;
    let port: u16 = lines.next()?.parse().ok()?;
    Some((pid, port))
}

/// Removes the PID file.
fn remove_pid_file() {
    let path = crate::paths::data_dir().join(PID_FILE_NAME);
    let _ = std::fs::remove_file(&path);
}

/// Checks if a process with the given PID is alive.
pub fn is_pid_alive(pid: u32) -> bool {
    check_process_running(pid)
}
