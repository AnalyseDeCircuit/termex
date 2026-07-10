//! Verifies the legacy → override DB migration logic that runs at iOS /
//! Android startup. Touches only the dependency-free inner helper so we
//! don't need to fight the global `OVERRIDE_DIR` `OnceLock`.

use std::fs;
use tempfile::tempdir;
use termex_core::paths;

fn write_file(path: &std::path::Path, content: &[u8]) {
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, content).unwrap();
}

#[test]
fn migrates_db_and_sidecars_when_only_legacy_exists() {
    let root = tempdir().unwrap();
    let legacy = root.path().join("termex");
    let new = root.path().join("data");

    write_file(&legacy.join("termex.db"), b"db-contents");
    write_file(&legacy.join("termex.db-wal"), b"wal");
    write_file(&legacy.join("termex.db-shm"), b"shm");

    paths::migrate_db_files(&legacy, &new);

    assert_eq!(fs::read(new.join("termex.db")).unwrap(), b"db-contents");
    assert_eq!(fs::read(new.join("termex.db-wal")).unwrap(), b"wal");
    assert_eq!(fs::read(new.join("termex.db-shm")).unwrap(), b"shm");
    assert!(!legacy.join("termex.db").exists());
}

#[test]
fn skips_when_new_dir_already_has_db() {
    let root = tempdir().unwrap();
    let legacy = root.path().join("termex");
    let new = root.path().join("data");

    write_file(&legacy.join("termex.db"), b"old");
    write_file(&new.join("termex.db"), b"keep-me");

    paths::migrate_db_files(&legacy, &new);

    // New DB untouched, legacy left alone (operator can investigate).
    assert_eq!(fs::read(new.join("termex.db")).unwrap(), b"keep-me");
    assert_eq!(fs::read(legacy.join("termex.db")).unwrap(), b"old");
}

#[test]
fn no_op_when_legacy_dir_is_empty() {
    let root = tempdir().unwrap();
    let legacy = root.path().join("termex");
    let new = root.path().join("data");
    fs::create_dir_all(&legacy).unwrap();

    paths::migrate_db_files(&legacy, &new);

    assert!(!new.join("termex.db").exists());
}

#[test]
fn no_op_when_paths_are_identical() {
    let root = tempdir().unwrap();
    let same = root.path().join("data");
    write_file(&same.join("termex.db"), b"x");

    paths::migrate_db_files(&same, &same);

    // Nothing should have changed — most importantly, no rename collision.
    assert_eq!(fs::read(same.join("termex.db")).unwrap(), b"x");
}
