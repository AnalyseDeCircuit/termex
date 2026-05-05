//! Tests for snippet JSON import/export (v0.46 spec §7.5).

use std::sync::Mutex;
use tempfile::TempDir;

use termex_core::storage::db::Database;
use termex_flutter_bridge::api::snippet::*;
use termex_flutter_bridge::db_state;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    dir
}

#[test]
fn test_snippet_export_creates_schema_version_1_file() {
    let _lock = TEST_LOCK.lock().unwrap();
    let dir = setup();

    snippet_create("ping".into(), "ping {{host}}".into(), Some("net".into()), vec![]).unwrap();
    snippet_create("ls".into(), "ls -la".into(), None, vec![]).unwrap();

    let path = dir.path().join("snips.json").to_string_lossy().to_string();
    snippet_export_json(path.clone()).expect("export should succeed");

    let raw = std::fs::read_to_string(&path).unwrap();
    assert!(raw.contains("\"schemaVersion\": 1"));
    assert!(raw.contains("\"ping\""));
    assert!(raw.contains("\"ls\""));
}

#[test]
fn test_snippet_export_then_import_roundtrip() {
    let _lock = TEST_LOCK.lock().unwrap();
    let dir = setup();

    snippet_create("a".into(), "cmd-a".into(), None, vec!["t1".into()]).unwrap();
    snippet_create("b".into(), "cmd-b".into(), None, vec![]).unwrap();

    let path = dir.path().join("snips.json").to_string_lossy().to_string();
    snippet_export_json(path.clone()).unwrap();

    // Wipe and re-import.
    for s in snippet_list(None, None).unwrap() {
        snippet_delete(s.id).unwrap();
    }
    assert!(snippet_list(None, None).unwrap().is_empty());

    let summary = snippet_import_json(path).expect("import should succeed");
    assert_eq!(summary.imported, 2);
    assert_eq!(summary.skipped_duplicates, 0);
    assert_eq!(summary.schema_version, 1);
    assert_eq!(snippet_list(None, None).unwrap().len(), 2);
}

#[test]
fn test_snippet_import_skips_duplicates_by_name() {
    let _lock = TEST_LOCK.lock().unwrap();
    let dir = setup();

    snippet_create("same".into(), "cmd-orig".into(), None, vec![]).unwrap();
    let path = dir.path().join("snips.json").to_string_lossy().to_string();
    snippet_export_json(path.clone()).unwrap();

    // Import into a DB that already has "same" — should skip.
    let summary = snippet_import_json(path).expect("import should succeed");
    assert_eq!(summary.imported, 0);
    assert_eq!(summary.skipped_duplicates, 1);
}

#[test]
fn test_snippet_import_nonexistent_file_errors() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let err = snippet_import_json("/tmp/nonexistent-snips-xyz.json".into()).unwrap_err();
    assert!(err.contains("read import"));
}
