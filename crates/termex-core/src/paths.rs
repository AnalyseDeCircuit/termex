//! Unified path resolver for portable and installed modes.
//!
//! Portable mode is activated when a `.portable` marker file exists
//! next to the executable. All data paths then resolve relative to
//! the executable directory instead of system user directories.

use std::path::PathBuf;
use std::sync::OnceLock;

/// Portable root directory, initialized once at startup.
/// `Some(path)` = portable mode, `None` = installed mode.
static PORTABLE_ROOT: OnceLock<Option<PathBuf>> = OnceLock::new();

/// Initializes the path resolver. Must be called once at app startup.
pub fn init() {
    PORTABLE_ROOT.get_or_init(|| {
        let exe = std::env::current_exe().ok()?;
        let exe_dir = exe.parent()?;
        if exe_dir.join(".portable").exists() {
            let data = exe_dir.join("data");
            // Ensure data directory exists
            let _ = std::fs::create_dir_all(&data);
            Some(data)
        } else {
            None
        }
    });
}

/// Returns true if running in portable mode.
pub fn is_portable() -> bool {
    PORTABLE_ROOT
        .get()
        .map(|r| r.is_some())
        .unwrap_or(false)
}

/// Data directory for database and recordings.
/// Portable: `<exe>/data/`  |  Installed: `~/.local/share/termex/` (or platform equivalent)
pub fn data_dir() -> PathBuf {
    if let Some(Some(root)) = PORTABLE_ROOT.get() {
        return root.clone();
    }
    dirs::data_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("termex")
}

/// App directory for fonts, models, binaries.
/// Portable: `<exe>/data/`  |  Installed: `~/.termex/` (or `%APPDATA%/termex/` on Windows)
pub fn app_dir() -> PathBuf {
    if let Some(Some(root)) = PORTABLE_ROOT.get() {
        return root.clone();
    }
    #[cfg(target_os = "windows")]
    {
        std::env::var("APPDATA")
            .map(|p| PathBuf::from(p).join("termex"))
            .unwrap_or_else(|_| PathBuf::from(".termex"))
    }
    #[cfg(not(target_os = "windows"))]
    {
        dirs::home_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join(".termex")
    }
}

/// Database file path.
pub fn db_path() -> PathBuf {
    data_dir().join("termex.db")
}

/// Custom fonts directory.
pub fn fonts_dir() -> PathBuf {
    app_dir().join("fonts")
}

/// Session recordings directory.
pub fn recordings_dir() -> PathBuf {
    data_dir().join("recordings")
}

/// AI models directory.
pub fn models_dir() -> PathBuf {
    app_dir().join("models")
}

/// AI binary directory (llama-server etc.).
pub fn bin_dir() -> PathBuf {
    app_dir().join("bin")
}

/// Lock file path — prevents two Termex instances from writing the same DB.
/// Written by `init_app()`, deleted by `close_app()`.
pub fn lock_path() -> PathBuf {
    db_path().with_extension("db.lock")
}
