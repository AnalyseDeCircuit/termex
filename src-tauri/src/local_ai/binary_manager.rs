use std::path::PathBuf;

/// Find llama-server binary from multiple sources:
/// 1. Custom path via LLAMA_SERVER_PATH environment variable
/// 2. Homebrew installation paths
/// 3. System PATH
pub async fn ensure_binary_exists(_bin_path: &PathBuf) -> Result<String, String> {
    eprintln!(">>> [BINARY_MANAGER] Looking for llama-server binary...");

    // 1. Check if custom path is configured via environment variable
    if let Ok(custom_path) = std::env::var("LLAMA_SERVER_PATH") {
        eprintln!(">>> [BINARY_MANAGER] Checking LLAMA_SERVER_PATH: {}", custom_path);
        if std::path::Path::new(&custom_path).exists() {
            if let Ok(test) = std::process::Command::new(&custom_path)
                .arg("--help")
                .output()
            {
                if test.status.success() {
                    eprintln!(">>> [BINARY_MANAGER] ✓ Custom llama-server path works: {}", custom_path);
                    return Ok(custom_path);
                } else {
                    eprintln!(">>> [BINARY_MANAGER] ✗ Custom path exists but --help failed");
                }
            } else {
                eprintln!(">>> [BINARY_MANAGER] ✗ Could not execute custom path");
            }
        } else {
            eprintln!(">>> [BINARY_MANAGER] ✗ Custom path does not exist: {}", custom_path);
        }
    }

    // 2. Check Homebrew installation paths (platform-specific)
    let homebrew_paths = vec![
        // macOS
        "/opt/homebrew/bin/llama-server",      // Apple Silicon (M1/M2/M3)
        "/usr/local/bin/llama-server",         // Intel Mac
        // Linux
        "/usr/bin/llama-server",
        "/usr/local/bin/llama-server",
        "/opt/llama-server/bin/llama-server",
        // Windows (in WSL or native)
        "C:\\Program Files\\llama-cpp\\llama-server.exe",
        "C:\\Program Files (x86)\\llama-cpp\\llama-server.exe",
    ];

    for path in homebrew_paths {
        if std::path::Path::new(path).exists() {
            eprintln!(">>> [BINARY_MANAGER] Found file at: {}", path);
            if let Ok(test) = std::process::Command::new(path)
                .arg("--help")
                .output()
            {
                if test.status.success() {
                    eprintln!(">>> [BINARY_MANAGER] ✓ Found working llama-server at: {}", path);
                    return Ok(path.to_string());
                } else {
                    eprintln!(">>> [BINARY_MANAGER] ✗ File exists at {} but --help failed", path);
                }
            } else {
                eprintln!(">>> [BINARY_MANAGER] ✗ Could not execute: {}", path);
            }
        }
    }

    // 3. Check PATH environment variable
    eprintln!(">>> [BINARY_MANAGER] Checking PATH for llama-server...");

    // First, try 'which' command
    if let Ok(output) = std::process::Command::new("which")
        .arg("llama-server")
        .output()
    {
        if output.status.success() {
            let path_str = String::from_utf8_lossy(&output.stdout).trim().to_string();
            eprintln!(">>> [BINARY_MANAGER] which found: {}", path_str);

            if let Ok(test) = std::process::Command::new(&path_str)
                .arg("--help")
                .output()
            {
                if test.status.success() {
                    eprintln!(">>> [BINARY_MANAGER] ✓ Found working llama-server via which: {}", path_str);
                    return Ok(path_str);
                } else {
                    eprintln!(">>> [BINARY_MANAGER] ✗ which found {} but --help failed", path_str);
                }
            }
        } else {
            eprintln!(">>> [BINARY_MANAGER] ✗ which command returned non-zero status");
        }
    } else {
        eprintln!(">>> [BINARY_MANAGER] ✗ which command not found (or failed)");
    }

    // 4. Try 'llama-server' directly (if it's in PATH and 'which' didn't work)
    eprintln!(">>> [BINARY_MANAGER] Trying to run 'llama-server' directly...");
    if let Ok(test) = std::process::Command::new("llama-server")
        .arg("--help")
        .output()
    {
        if test.status.success() {
            eprintln!(">>> [BINARY_MANAGER] ✓ Found working llama-server via direct call");
            return Ok("llama-server".to_string());
        } else {
            eprintln!(">>> [BINARY_MANAGER] ✗ Direct call to llama-server failed");
        }
    } else {
        eprintln!(">>> [BINARY_MANAGER] ✗ Could not execute llama-server directly");
    }

    // Not found
    eprintln!(">>> [BINARY_MANAGER] llama-server not found!");
    let help_msg = r#"

╔════════════════════════════════════════════════════════════╗
║          llama-server not found                            ║
╚════════════════════════════════════════════════════════════╝

RECOMMENDED: Install llama-cpp via Homebrew
  $ brew install llama.cpp

Then restart the application.

ALTERNATIVE: Set custom path via environment variable
  $ export LLAMA_SERVER_PATH=/path/to/llama-server
  Then restart the application.

VERIFY INSTALLATION:
  $ which llama-server       # Should show the path
  $ llama-server --help      # Should show help text
"#;

    eprintln!("{}", help_msg);
    Err("llama-server not found. Please install via: brew install llama.cpp".to_string())
}
