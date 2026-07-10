//! Unified path resolver for portable and installed modes.
//!
//! Portable mode is activated when a `.portable` marker file exists
//! next to the executable. All data paths then resolve relative to
//! the executable directory instead of system user directories.

use std::path::{Path, PathBuf};
use std::sync::OnceLock;

/// Portable root directory, initialized once at startup.
/// `Some(path)` = portable mode, `None` = installed mode.
static PORTABLE_ROOT: OnceLock<Option<PathBuf>> = OnceLock::new();

/// Override for data/app directories — populated by mobile platforms where
/// `dirs::data_dir()` doesn't know about sandbox-app-writable locations.
/// Set via [`override_app_data_dir`] before [`init`] (or before the first
/// `data_dir()` / `app_dir()` call).
static OVERRIDE_DIR: OnceLock<PathBuf> = OnceLock::new();

/// Forces both `data_dir()` and `app_dir()` to resolve under `dir`.
/// Used by mobile (iOS / Android) host code to point the Rust core at the
/// platform-provided writable app directory (returned by Flutter's
/// `path_provider.getApplicationSupportDirectory()`).
pub fn override_app_data_dir(dir: PathBuf) {
    let _ = OVERRIDE_DIR.set(dir);
}

/// One-shot migration for users upgrading from a pre-override build.
///
/// Pre-override iOS / Android builds stored the DB under
/// `dirs::data_dir().join("termex")` (e.g. `<sandbox>/Library/Application
/// Support/termex/termex.db`). After `override_app_data_dir` lands, the
/// DB lives at `<override>/data/termex.db` instead. Without this move,
/// the upgrade looks identical to a wiped account — server entries
/// "disappear" while still sitting on disk in the old location.
///
/// Safe to call unconditionally:
///   - no-op when paths are identical (e.g. desktop, where override is unset)
///   - no-op when the new location already has a DB (already migrated)
///   - no-op when the legacy location has no DB (first install)
///
/// Must be called *after* [`override_app_data_dir`] and *before*
/// [`db_path`] is used by `Database::open`.
pub fn migrate_legacy_data_dir_if_needed() {
    let new_dir = data_dir();
    // Compute the legacy path by going around the override — the legacy
    // resolver was just `dirs::data_dir().join("termex")`.
    let legacy_dir = match dirs::data_dir() {
        Some(d) => d.join("termex"),
        None => return,
    };
    migrate_db_files(&legacy_dir, &new_dir);
}

/// Inner, dependency-free migration step used by
/// [`migrate_legacy_data_dir_if_needed`] and exercised by unit tests.
/// Moves `termex.db` + its SQLite sidecar files from `legacy_dir` to
/// `new_dir` only when it's clearly safe (see the wrapper doc for the
/// no-op cases).
pub fn migrate_db_files(legacy_dir: &Path, new_dir: &Path) {
    if legacy_dir == new_dir {
        return;
    }
    if !legacy_dir.join("termex.db").exists() {
        return;
    }
    if new_dir.join("termex.db").exists() {
        return;
    }
    if std::fs::create_dir_all(new_dir).is_err() {
        return;
    }
    // Move the DB + its SQLite sidecar files. Leave the legacy directory
    // in place — recordings/ and lock files can stay; the only thing we
    // actively need at the new path is the database itself.
    for name in ["termex.db", "termex.db-wal", "termex.db-shm"] {
        let from = legacy_dir.join(name);
        if from.exists() {
            let _ = std::fs::rename(&from, new_dir.join(name));
        }
    }
}

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
    if let Some(root) = OVERRIDE_DIR.get() {
        return root.join("data");
    }
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
    if let Some(root) = OVERRIDE_DIR.get() {
        return root.clone();
    }
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
