//! Recording persistence against a real database.
//!
//! Written because a delete reported as failing in the app could not be
//! reproduced by inspection: the Dart wiring, the FRB binding and the SQL
//! all read correctly, so the store itself is what was left to rule out.

use std::sync::Mutex;
use tempfile::TempDir;
use termex_core::storage::db::Database;
use termex_flutter_bridge::{api::recording::*, db_state};

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    dir
}

/// Inserts a row the same way `recording_start` does, plus a file on disk.
fn seed(dir: &TempDir, id: &str) -> String {
    let path = dir.path().join(format!("{id}.cast"));
    std::fs::write(&path, "{\"version\":2}\n[0.5,\"o\",\"hi\"]\n").unwrap();
    let path_str = path.to_string_lossy().to_string();
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "INSERT INTO recordings
                   (id, session_id, server_id, server_name, file_path,
                    cols, rows, started_at, created_at)
                 VALUES (?1, 'sess', 'srv', 'prod', ?2, 80, 24,
                         '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')",
                rusqlite::params![id, path_str],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
    .unwrap();
    path_str
}

#[test]
fn delete_removes_the_row_and_the_file() {
    let _lock = TEST_LOCK.lock().unwrap();
    let dir = setup();
    let path = seed(&dir, "rec-1");

    recording_delete("rec-1".into()).expect("delete must not error");

    assert!(recording_list_full().unwrap().is_empty(), "row survived");
    assert!(
        !std::path::Path::new(&path).exists(),
        "the .cast file was left on disk"
    );
}

#[test]
fn delete_leaves_the_other_recordings_alone() {
    let _lock = TEST_LOCK.lock().unwrap();
    let dir = setup();
    seed(&dir, "rec-1");
    let kept = seed(&dir, "rec-2");

    recording_delete("rec-1".into()).unwrap();

    let rest = recording_list_full().unwrap();
    assert_eq!(rest.len(), 1);
    assert_eq!(rest[0].id, "rec-2");
    assert!(std::path::Path::new(&kept).exists());
}

#[test]
fn deleting_an_unknown_id_is_not_an_error() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    // The list and the store can disagree after an external change; a stale
    // row must not raise a failure toast the user cannot act on.
    recording_delete("no-such-recording".into()).expect("must be a no-op");
}

#[test]
fn a_missing_cast_file_does_not_fail_the_delete() {
    let _lock = TEST_LOCK.lock().unwrap();
    let dir = setup();
    let path = seed(&dir, "rec-1");
    std::fs::remove_file(&path).unwrap();

    recording_delete("rec-1".into()).expect("delete must not error");
    assert!(recording_list_full().unwrap().is_empty());
}
