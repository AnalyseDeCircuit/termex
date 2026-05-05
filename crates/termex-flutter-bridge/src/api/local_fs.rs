/// Local filesystem operations exposed to Flutter via FRB.
///
/// These mirror the SFTP file-list/CRUD interface so that the SFTP panel's
/// local pane can use the same Dart data types regardless of whether it is
/// talking to the local disk or a remote server.
use std::fs;
use std::path::{Path, PathBuf};
use std::time::UNIX_EPOCH;

// ─── DTOs ────────────────────────────────────────────────────────────────────

/// A local filesystem entry (file or directory).
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LocalFileDto {
    pub name: String,
    pub path: String,
    pub is_dir: bool,
    pub is_symlink: bool,
    pub size: u64,
    /// Unix permission bits (e.g. 0o644).  `None` on platforms that don't
    /// expose POSIX permissions.
    pub permissions: Option<u32>,
    /// Seconds since Unix epoch, or `None` if unavailable.
    pub modified_at: Option<i64>,
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

fn metadata_to_dto(path: &Path, name: String) -> Result<LocalFileDto, String> {
    let meta = path.symlink_metadata().map_err(|e| e.to_string())?;
    let is_symlink = meta.file_type().is_symlink();
    // Follow the symlink for size / is_dir.
    let follow_meta = if is_symlink {
        path.metadata().unwrap_or(meta.clone())
    } else {
        meta.clone()
    };

    let modified_at = follow_meta
        .modified()
        .ok()
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_secs() as i64);

    #[cfg(unix)]
    let permissions = {
        use std::os::unix::fs::PermissionsExt;
        Some(follow_meta.permissions().mode())
    };
    #[cfg(not(unix))]
    let permissions: Option<u32> = None;

    Ok(LocalFileDto {
        name,
        path: path.to_string_lossy().into_owned(),
        is_dir: follow_meta.is_dir(),
        is_symlink,
        size: follow_meta.len(),
        permissions,
        modified_at,
    })
}

// ─── API ─────────────────────────────────────────────────────────────────────

/// Returns the user's home directory.
pub fn local_home_dir() -> Result<String, String> {
    dirs::home_dir()
        .map(|p| p.to_string_lossy().into_owned())
        .ok_or_else(|| "Could not determine home directory".into())
}

/// Lists the contents of a local directory, sorted: dirs first, then files,
/// both groups sorted alphabetically (case-insensitive).
pub fn local_list_dir(path: String) -> Result<Vec<LocalFileDto>, String> {
    let dir = Path::new(&path);
    if !dir.is_dir() {
        return Err(format!("Not a directory: {path}"));
    }

    let mut entries: Vec<LocalFileDto> = fs::read_dir(dir)
        .map_err(|e| e.to_string())?
        .filter_map(|res| {
            let entry = res.ok()?;
            let name = entry.file_name().to_string_lossy().into_owned();
            // Skip hidden files beginning with `.` — callers can opt-in later.
            metadata_to_dto(&entry.path(), name).ok()
        })
        .collect();

    entries.sort_by(|a, b| {
        b.is_dir
            .cmp(&a.is_dir)
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });

    Ok(entries)
}

/// Stats a single local path.
pub fn local_stat(path: String) -> Result<LocalFileDto, String> {
    let p = PathBuf::from(&path);
    let name = p
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_else(|| path.clone());
    metadata_to_dto(&p, name)
}

/// Renames (moves) a local path.
pub fn local_rename(from: String, to: String) -> Result<(), String> {
    fs::rename(&from, &to).map_err(|e| e.to_string())
}

/// Deletes a file.  Use [local_rmdir] for directories.
pub fn local_delete(path: String) -> Result<(), String> {
    fs::remove_file(&path).map_err(|e| e.to_string())
}

/// Deletes a directory and all its contents recursively.
pub fn local_rmdir(path: String) -> Result<(), String> {
    fs::remove_dir_all(&path).map_err(|e| e.to_string())
}

/// Creates a directory (and all missing parents).
pub fn local_mkdir(path: String) -> Result<(), String> {
    fs::create_dir_all(&path).map_err(|e| e.to_string())
}

/// Creates an empty file.  Fails if the file already exists.
pub fn local_create_file(path: String) -> Result<(), String> {
    fs::File::create_new(&path)
        .map(|_| ())
        .map_err(|e| e.to_string())
}

/// Opens a URL in the default browser / handler.
pub fn open_url(url: String) -> Result<(), String> {
    open::that(&url).map_err(|e| e.to_string())
}

/// Returns the parent directory of `path`, or an error if there is none.
pub fn local_parent(path: String) -> Result<String, String> {
    Path::new(&path)
        .parent()
        .map(|p| p.to_string_lossy().into_owned())
        .ok_or_else(|| format!("No parent for: {path}"))
}

/// Returns `true` if `path` exists on the local filesystem.
pub fn local_exists(path: String) -> bool {
    Path::new(&path).exists()
}
