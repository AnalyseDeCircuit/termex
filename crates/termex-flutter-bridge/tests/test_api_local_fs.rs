use std::fs;
use tempfile::TempDir;
use termex_flutter_bridge::api::local_fs::*;

fn tmp() -> TempDir {
    TempDir::new().unwrap()
}

// ─── local_home_dir ───────────────────────────────────────────────────────────

#[test]
fn test_local_home_dir_returns_non_empty_string() {
    let home = local_home_dir().unwrap();
    assert!(!home.is_empty());
}

// ─── local_list_dir ───────────────────────────────────────────────────────────

#[test]
fn test_local_list_dir_empty_directory() {
    let dir = tmp();
    let entries = local_list_dir(dir.path().to_string_lossy().into()).unwrap();
    assert!(entries.is_empty());
}

#[test]
fn test_local_list_dir_shows_files_and_dirs() {
    let dir = tmp();
    fs::create_dir(dir.path().join("subdir")).unwrap();
    fs::write(dir.path().join("file.txt"), b"hello").unwrap();

    let entries = local_list_dir(dir.path().to_string_lossy().into()).unwrap();
    assert_eq!(entries.len(), 2);
    // Dirs come first.
    assert!(entries[0].is_dir);
    assert_eq!(entries[0].name, "subdir");
    assert!(!entries[1].is_dir);
    assert_eq!(entries[1].name, "file.txt");
}

#[test]
fn test_local_list_dir_sorted_alphabetically_within_group() {
    let dir = tmp();
    fs::write(dir.path().join("zebra.txt"), b"").unwrap();
    fs::write(dir.path().join("alpha.txt"), b"").unwrap();
    fs::create_dir(dir.path().join("z_dir")).unwrap();
    fs::create_dir(dir.path().join("a_dir")).unwrap();

    let entries = local_list_dir(dir.path().to_string_lossy().into()).unwrap();
    // Dirs first, alphabetical: a_dir, z_dir, alpha.txt, zebra.txt
    assert_eq!(entries[0].name, "a_dir");
    assert_eq!(entries[1].name, "z_dir");
    assert_eq!(entries[2].name, "alpha.txt");
    assert_eq!(entries[3].name, "zebra.txt");
}

#[test]
fn test_local_list_dir_invalid_path_returns_error() {
    let result = local_list_dir("/nonexistent/path/xyz123".into());
    assert!(result.is_err());
}

// ─── local_stat ──────────────────────────────────────────────────────────────

#[test]
fn test_local_stat_file() {
    let dir = tmp();
    let f = dir.path().join("test.txt");
    fs::write(&f, b"hello world").unwrap();

    let dto = local_stat(f.to_string_lossy().into()).unwrap();
    assert_eq!(dto.name, "test.txt");
    assert!(!dto.is_dir);
    assert_eq!(dto.size, 11);
}

#[test]
fn test_local_stat_directory() {
    let dir = tmp();
    let dto = local_stat(dir.path().to_string_lossy().into()).unwrap();
    assert!(dto.is_dir);
}

#[test]
fn test_local_stat_nonexistent_returns_error() {
    let result = local_stat("/does/not/exist/file.txt".into());
    assert!(result.is_err());
}

// ─── local_mkdir ─────────────────────────────────────────────────────────────

#[test]
fn test_local_mkdir_creates_directory() {
    let dir = tmp();
    let new_dir = dir.path().join("newdir").join("nested");
    local_mkdir(new_dir.to_string_lossy().into()).unwrap();
    assert!(new_dir.is_dir());
}

// ─── local_create_file ───────────────────────────────────────────────────────

#[test]
fn test_local_create_file_creates_empty_file() {
    let dir = tmp();
    let f = dir.path().join("new.txt");
    local_create_file(f.to_string_lossy().into()).unwrap();
    assert!(f.exists());
    assert_eq!(fs::read(&f).unwrap(), b"");
}

#[test]
fn test_local_create_file_fails_if_exists() {
    let dir = tmp();
    let f = dir.path().join("exists.txt");
    fs::write(&f, b"content").unwrap();
    let result = local_create_file(f.to_string_lossy().into());
    assert!(result.is_err());
}

// ─── local_rename ────────────────────────────────────────────────────────────

#[test]
fn test_local_rename_file() {
    let dir = tmp();
    let src = dir.path().join("old.txt");
    let dst = dir.path().join("new.txt");
    fs::write(&src, b"data").unwrap();

    local_rename(
        src.to_string_lossy().into(),
        dst.to_string_lossy().into(),
    )
    .unwrap();

    assert!(!src.exists());
    assert!(dst.exists());
}

// ─── local_delete ────────────────────────────────────────────────────────────

#[test]
fn test_local_delete_file() {
    let dir = tmp();
    let f = dir.path().join("to_delete.txt");
    fs::write(&f, b"").unwrap();

    local_delete(f.to_string_lossy().into()).unwrap();
    assert!(!f.exists());
}

#[test]
fn test_local_delete_nonexistent_returns_error() {
    let result = local_delete("/nonexistent/file.txt".into());
    assert!(result.is_err());
}

// ─── local_rmdir ─────────────────────────────────────────────────────────────

#[test]
fn test_local_rmdir_removes_directory_recursively() {
    let dir = tmp();
    let sub = dir.path().join("sub");
    fs::create_dir(&sub).unwrap();
    fs::write(sub.join("file.txt"), b"").unwrap();

    local_rmdir(sub.to_string_lossy().into()).unwrap();
    assert!(!sub.exists());
}

// ─── local_parent ────────────────────────────────────────────────────────────

#[test]
fn test_local_parent_returns_parent() {
    let parent = local_parent("/home/user/file.txt".into()).unwrap();
    assert_eq!(parent, "/home/user");
}

#[test]
fn test_local_parent_of_root_returns_error() {
    let result = local_parent("/".into());
    assert!(result.is_err());
}

// ─── local_exists ────────────────────────────────────────────────────────────

#[test]
fn test_local_exists_true_for_real_path() {
    let dir = tmp();
    assert!(local_exists(dir.path().to_string_lossy().into()));
}

#[test]
fn test_local_exists_false_for_missing_path() {
    assert!(!local_exists("/nonexistent/xyz".into()));
}
