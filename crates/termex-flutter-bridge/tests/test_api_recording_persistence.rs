//! v0.47 recording persistence tests: DB-backed CRUD + parent/encryption + cleanup.

use std::sync::Mutex;
use tempfile::TempDir;

use termex_core::storage::db::Database;
use termex_flutter_bridge::api::recording::*;
use termex_flutter_bridge::db_state;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    dir
}

#[test]
fn test_recording_render_filename_is_deterministic_shape() {
    let name = recording_render_filename("web 01 (prod)");
    assert!(name.ends_with(".cast"));
    // Non-alphanumeric chars → _
    assert!(name.starts_with("web_01__prod_"));
    // Timestamp 15 chars YYYYMMDDTHHMMSS.
    assert!(name.contains("T"));
    // Random hex6 appears before the extension.
    let stem = name.trim_end_matches(".cast");
    let segs: Vec<&str> = stem.split('_').collect();
    assert_eq!(segs.last().unwrap().len(), 6);
    assert!(segs.last().unwrap().chars().all(|c| c.is_ascii_hexdigit()));
}

#[test]
fn test_recording_render_part_filename() {
    let part = recording_render_part_filename("web_20260420T010203_abcdef.cast", 2);
    assert_eq!(part, "web_20260420T010203_abcdef_part2.cast");
    let part5 = recording_render_part_filename("foo.cast", 5);
    assert_eq!(part5, "foo_part5.cast");
}

#[test]
fn test_recording_start_persists_row() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let id = recording_start("session-x".into(), Some("web-01".into())).unwrap();
    let all = recording_list_full().unwrap();
    assert_eq!(all.len(), 1);
    assert_eq!(all[0].id, id);
    assert_eq!(all[0].session_id, "session-x");
    assert!(!all[0].is_encrypted);
    assert!(all[0].parent_id.is_none());
}

#[test]
fn test_recording_stop_sets_ended_at() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let id = recording_start("s".into(), None).unwrap();
    recording_stop(id.clone()).unwrap();

    let all = recording_list_full().unwrap();
    assert_eq!(all.len(), 1);
    assert!(all[0].ended_at.is_some());
}

#[test]
fn test_recording_register_part_links_to_parent() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let parent_id =
        recording_start("s1".into(), Some("web".into())).unwrap();
    let part_id = recording_register_part(
        parent_id.clone(),
        "s1".into(),
        "/tmp/web_part2.cast".into(),
    )
    .unwrap();

    let all = recording_list_full().unwrap();
    assert_eq!(all.len(), 2);
    let part = all.iter().find(|r| r.id == part_id).unwrap();
    assert_eq!(part.parent_id.as_deref(), Some(parent_id.as_str()));
}

#[test]
fn test_recording_delete_group_cascades() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let parent = recording_start("s".into(), Some("a".into())).unwrap();
    let _ = recording_register_part(parent.clone(), "s".into(), "/tmp/p2.cast".into()).unwrap();
    let _ = recording_register_part(parent.clone(), "s".into(), "/tmp/p3.cast".into()).unwrap();
    assert_eq!(recording_list_full().unwrap().len(), 3);

    let n = recording_delete_group(parent).unwrap();
    assert_eq!(n, 3);
    assert!(recording_list_full().unwrap().is_empty());
}

#[test]
fn test_recording_mark_encrypted_flips_flag() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let id = recording_start("s".into(), None).unwrap();
    assert!(!recording_list_full().unwrap()[0].is_encrypted);

    recording_mark_encrypted(id).unwrap();
    assert!(recording_list_full().unwrap()[0].is_encrypted);
}

#[test]
fn test_recording_cleanup_expired_deletes_old_rows() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    // Insert a recording with a backdated created_at.
    let _ = recording_start("s".into(), Some("old".into())).unwrap();
    let backdated = (chrono::Utc::now() - chrono::Duration::days(60)).to_rfc3339();
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute("UPDATE recordings SET created_at = ?1", rusqlite::params![backdated])?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
    .unwrap();

    let deleted = recording_cleanup_expired(30).unwrap();
    assert_eq!(deleted, 1);
    assert!(recording_list_full().unwrap().is_empty());
}

#[test]
fn test_recording_cleanup_zero_days_is_noop() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let _ = recording_start("s".into(), None).unwrap();
    let deleted = recording_cleanup_expired(0).unwrap();
    assert_eq!(deleted, 0);
    assert_eq!(recording_list_full().unwrap().len(), 1);
}
