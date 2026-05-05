use std::path::Path;

/// Check available disk space in bytes for the filesystem containing `path`.
///
/// Walks up the directory tree until a path that exists is found, then calls
/// `fs2::available_space` on it. Returns `None` only when every ancestor fails
/// to stat (e.g. the root is missing), which should not happen on a functioning
/// system.
pub fn get_available_space(path: &Path) -> Option<u64> {
    let mut cursor = path;
    loop {
        if cursor.exists() {
            return fs2::available_space(cursor).ok();
        }
        match cursor.parent() {
            Some(parent) if parent != cursor => cursor = parent,
            _ => return None,
        }
    }
}

/// Check if there's enough space for a download.
///
/// # Arguments
/// * `target_path` - Path where the file will be stored
/// * `required_bytes` - Number of bytes needed
/// * `buffer_factor` - Safety buffer multiplier (e.g., 1.2 for 20% extra)
///
/// Returns true if there's enough space (with safety buffer)
pub fn has_enough_space(
    target_path: &Path,
    required_bytes: u64,
    buffer_factor: f64,
) -> Result<bool, String> {
    let required_with_buffer = (required_bytes as f64 * buffer_factor) as u64;

    match get_available_space(target_path) {
        Some(available) => Ok(available >= required_with_buffer),
        None => Err("Unable to check available disk space".to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_available_space_returns_some_on_existing_dir() {
        let avail = get_available_space(Path::new("/tmp"));
        assert!(avail.is_some(), "expected /tmp to report available space");
        assert!(avail.unwrap() > 0, "expected nonzero available bytes");
    }

    #[test]
    fn test_get_available_space_walks_up_for_missing_path() {
        let missing = Path::new("/tmp/__termex_nonexistent_abc_xyz__/sub");
        let avail = get_available_space(missing);
        assert!(avail.is_some(), "should fall back to an existing ancestor");
    }

    #[test]
    fn test_has_enough_space_true_for_small_request() {
        // 1 KB with 1.2x buffer on /tmp almost certainly fits.
        let ok = has_enough_space(Path::new("/tmp"), 1024, 1.2);
        assert_eq!(ok, Ok(true));
    }
}
