//! Tests for local filesystem commands and security status.

#[test]
fn test_local_home_dir_exists() {
    let home = dirs::home_dir();
    assert!(home.is_some());
    assert!(home.unwrap().exists());
}

#[test]
fn test_local_list_dir_root() {
    let entries = std::fs::read_dir("/").unwrap();
    let count = entries.count();
    assert!(count > 0);
}

#[test]
fn test_local_list_dir_home() {
    let home = dirs::home_dir().unwrap();
    let entries: Vec<_> = std::fs::read_dir(&home)
        .unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| !e.file_name().to_string_lossy().starts_with('.'))
        .collect();
    // Home directory should have some non-hidden entries
    assert!(!entries.is_empty());
}

#[test]
fn test_local_list_dir_nonexistent() {
    let result = std::fs::read_dir("/nonexistent/path/12345");
    assert!(result.is_err());
}

#[test]
fn test_local_list_dir_sorting() {
    // Create a temp dir with known files
    let dir = std::env::temp_dir().join("termex-test-sort");
    let _ = std::fs::create_dir_all(&dir);
    let _ = std::fs::create_dir(dir.join("zz_dir"));
    let _ = std::fs::create_dir(dir.join("aa_dir"));
    let _ = std::fs::write(dir.join("bb_file.txt"), "test");
    let _ = std::fs::write(dir.join("aa_file.txt"), "test");

    let mut entries: Vec<(bool, String)> = std::fs::read_dir(&dir)
        .unwrap()
        .filter_map(|e| e.ok())
        .map(|e| {
            let meta = e.metadata().unwrap();
            (meta.is_dir(), e.file_name().to_string_lossy().to_string())
        })
        .collect();

    // Sort: dirs first, then by name
    entries.sort_by(|a, b| {
        if a.0 != b.0 { return if a.0 { std::cmp::Ordering::Less } else { std::cmp::Ordering::Greater }; }
        a.1.to_lowercase().cmp(&b.1.to_lowercase())
    });

    assert!(entries[0].0); // first entry is a dir
    assert_eq!(entries[0].1, "aa_dir");
    assert_eq!(entries[1].1, "zz_dir");
    assert!(!entries[2].0); // files after dirs

    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn test_keychain_availability_check() {
    // Just verify it doesn't panic
    let available = termex_lib::keychain::is_available();
    // Result depends on environment
    let _ = available;
}
