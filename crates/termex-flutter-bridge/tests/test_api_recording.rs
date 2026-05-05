use std::sync::{Mutex, MutexGuard};

use termex_flutter_bridge::api::recording::*;

static REC_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> MutexGuard<'static, ()> {
    let guard = REC_LOCK.lock().unwrap();
    _test_clear_registry();
    guard
}

// ─── Start ────────────────────────────────────────────────────────────────────

#[test]
fn test_recording_start_returns_id() {
    let _guard = setup();
    let id = recording_start("session-1".into(), None).unwrap();
    assert!(!id.is_empty(), "recording id should not be empty");
}

#[test]
fn test_recording_start_with_title() {
    let _guard = setup();
    let id = recording_start("session-2".into(), Some("My Recording".into())).unwrap();
    assert!(!id.is_empty());
}

#[test]
fn test_recording_start_unique_ids() {
    let _guard = setup();
    let id1 = recording_start("session-3".into(), None).unwrap();
    let id2 = recording_start("session-3".into(), None).unwrap();
    assert_ne!(id1, id2, "each recording should get a unique id");
}

// ─── Stop ─────────────────────────────────────────────────────────────────────

#[test]
fn test_recording_stop_returns_entry() {
    let _guard = setup();
    let id = recording_start("session-stop".into(), Some("Test".into())).unwrap();
    let entry = recording_stop(id.clone()).unwrap();
    assert_eq!(entry.id, id);
    // v0.47 filename is {server}_{timestamp}_{rand6}.cast — no UUID.
    assert!(entry.file_path.ends_with(".cast"), "file should be .cast");
    assert!(entry.file_path.contains("/"), "file_path should be absolute-ish");
}

#[test]
fn test_recording_stop_file_path_format() {
    let _guard = setup();
    let id = recording_start("session-path".into(), None).unwrap();
    let entry = recording_stop(id.clone()).unwrap();
    assert!(entry.file_path.ends_with(".cast"), "file should be .cast");
}

// ─── List ─────────────────────────────────────────────────────────────────────

#[test]
fn test_recording_list_empty() {
    let list = recording_list().unwrap();
    assert!(list.is_empty(), "recording_list stub returns empty vec");
}

// ─── Delete ───────────────────────────────────────────────────────────────────

#[test]
fn test_recording_delete_ok() {
    let _guard = setup();
    let id = recording_start("session-del".into(), None).unwrap();
    recording_delete(id.clone()).unwrap();
    // Idempotent: deleting a non-existent id should also succeed.
    recording_delete(id).unwrap();
}

// ─── Get Path ─────────────────────────────────────────────────────────────────

#[test]
fn test_recording_get_path_returns_cast_path() {
    let id = "test-id-abc123".to_string();
    let path = recording_get_path(id.clone()).unwrap();
    assert!(path.contains(&id));
    assert!(path.ends_with(".cast"));
}

// ─── Export ───────────────────────────────────────────────────────────────────

#[test]
fn test_recording_export_ok() {
    recording_export("any-id".into(), "/tmp/export.cast".into()).unwrap();
}
