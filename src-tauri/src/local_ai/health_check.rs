use std::time::Duration;
use tokio::time::sleep;
use crate::state::AppState;
use std::net::TcpStream;

/// Check if a port is currently listening by attempting a TCP connection.
/// Tries multiple addresses: 127.0.0.1, localhost, and 0.0.0.0
/// Returns Ok(()) if the port is open, Err if not.
pub async fn is_port_listening(port: u16) -> bool {
    // Try 127.0.0.1 first
    if let Ok(_) = TcpStream::connect(("127.0.0.1", port)) {
        return true;
    }

    // Try localhost
    if let Ok(_) = TcpStream::connect(("localhost", port)) {
        return true;
    }

    // Try 0.0.0.0 (all interfaces)
    if let Ok(_) = TcpStream::connect(("0.0.0.0", port)) {
        return true;
    }

    false
}

/// Wait for a port to start listening with exponential backoff.
///
/// # Arguments
/// * `port` - The port number to check
/// * `max_wait_secs` - Maximum time to wait in seconds (default: 30)
///
/// # Returns
/// Ok(()) if port becomes available, Err(String) if timeout or other error
pub async fn wait_for_port(port: u16, max_wait_secs: u64) -> Result<(), String> {
    eprintln!(">>> [HEALTH_CHECK] wait_for_port called for port {} with timeout {}s", port, max_wait_secs);
    let start = std::time::Instant::now();
    let max_duration = Duration::from_secs(max_wait_secs);
    let mut attempt = 0u32;

    loop {
        if is_port_listening(port).await {
            eprintln!(">>> [HEALTH_CHECK] Port {} is now listening (attempt {}, elapsed: {}s)", port, attempt, start.elapsed().as_secs());
            log::info!("Port {} is now listening (attempt {})", port, attempt);
            return Ok(());
        }

        if start.elapsed() > max_duration {
            eprintln!(">>> [HEALTH_CHECK] Timeout waiting for port {} (waited {} seconds)", port, max_wait_secs);
            return Err(format!(
                "Timeout waiting for port {} to listen (waited {} seconds)",
                port, max_wait_secs
            ));
        }

        // Exponential backoff with cap: 10ms, 20ms, 40ms, 80ms, 160ms, 300ms, 300ms...
        // Cap at attempt 5 to avoid overflow: 2^5 = 32, 10 * 32 = 320ms, min with 300 = 300ms
        let capped_attempt = std::cmp::min(attempt, 5);
        let backoff_ms = std::cmp::min(10 * (1u64 << capped_attempt), 300);

        // Print progress every 5 seconds
        if attempt % 10 == 0 {
            eprintln!(">>> [HEALTH_CHECK] Still waiting... Attempt {}: Port {} not listening (elapsed: {}s)", attempt, port, start.elapsed().as_secs());
        }
        log::debug!("Port {} not listening yet, waiting {}ms (attempt {})", port, backoff_ms, attempt);

        sleep(Duration::from_millis(backoff_ms)).await;
        attempt += 1;
    }
}

/// Starts a background health check task that monitors the llama-server process.
/// Restarts the engine if it crashes, with exponential backoff.
///
/// # Arguments
/// * `app_state` - Reference to the shared application state
/// * `check_interval` - How often to check the process (in seconds)
/// * `max_retries` - Maximum number of restart attempts
pub async fn start_health_check(
    app_state: std::sync::Arc<AppState>,
    check_interval: u64,
    max_retries: u32,
) {
    tokio::spawn(async move {
        let mut consecutive_failures = 0u32;

        loop {
            sleep(Duration::from_secs(check_interval)).await;

            let server = app_state.llama_server.read().await;

            // Check if engine is supposed to be running but isn't
            if server.process_id.is_some() && !server.is_running() {
                drop(server);

                consecutive_failures += 1;
                log::warn!(
                    "llama-server process died (attempt {}), attempting restart...",
                    consecutive_failures
                );

                if consecutive_failures <= max_retries {
                    // Attempt to restart using the last known model
                    if let Some(model_path) = {
                        let s = app_state.llama_server.read().await;
                        s.loaded_model.clone()
                    } {
                        let mut server = app_state.llama_server.write().await;

                        // Reset state first
                        let _ = server.stop().await;

                        // Exponential backoff: 1s, 2s, 4s, 8s...
                        let backoff_secs = 2u64.pow(consecutive_failures.saturating_sub(1));
                        sleep(Duration::from_secs(backoff_secs)).await;

                        // Attempt restart
                        let binary_path = get_llama_binary_path();
                        match server
                            .start(binary_path, std::path::PathBuf::from(&model_path))
                            .await
                        {
                            Ok(_) => {
                                consecutive_failures = 0;
                                log::info!("llama-server restarted successfully");
                            }
                            Err(e) => {
                                log::error!("Failed to restart llama-server: {}", e);
                            }
                        }
                    }
                } else {
                    log::error!(
                        "llama-server exceeded max retries ({}), stopping health check",
                        max_retries
                    );
                    // Stop attempting restarts
                    let mut server = app_state.llama_server.write().await;
                    let _ = server.stop().await;
                    break;
                }
            } else {
                // Process is running normally
                consecutive_failures = 0;
            }
        }
    });
}

/// Get the path to the llama-server binary based on the current platform.
fn get_llama_binary_path() -> std::path::PathBuf {
    let app_data_dir = get_app_data_dir();
    let bin_dir = app_data_dir.join("bin");

    #[cfg(target_os = "macos")]
    {
        #[cfg(target_arch = "x86_64")]
        let binary = bin_dir.join("llama-server-macos-x64");
        #[cfg(target_arch = "aarch64")]
        let binary = bin_dir.join("llama-server-macos-arm64");

        binary
    }

    #[cfg(target_os = "windows")]
    {
        bin_dir.join("llama-server-windows-x64.exe")
    }

    #[cfg(target_os = "linux")]
    {
        #[cfg(target_arch = "x86_64")]
        let binary = bin_dir.join("llama-server-linux-x64");
        #[cfg(target_arch = "aarch64")]
        let binary = bin_dir.join("llama-server-linux-arm64");

        binary
    }
}

/// Get the ~/.termex/ directory, using platform-specific paths.
fn get_app_data_dir() -> std::path::PathBuf {
    #[cfg(target_os = "macos")]
    {
        let home = dirs::home_dir().unwrap_or_else(|| std::path::PathBuf::from("~"));
        home.join(".termex")
    }

    #[cfg(target_os = "windows")]
    {
        let app_data = std::env::var("APPDATA")
            .unwrap_or_else(|_| std::path::PathBuf::from(".").to_string_lossy().to_string());
        std::path::PathBuf::from(app_data).join("termex")
    }

    #[cfg(target_os = "linux")]
    {
        let home = dirs::home_dir().unwrap_or_else(|| std::path::PathBuf::from("~"));
        home.join(".termex")
    }
}
