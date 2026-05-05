//! v0.47 port forward persistence tests: bind_ip, conflict detection, DB.

use std::sync::Mutex;
use tempfile::TempDir;

use termex_core::storage::db::Database;
use termex_flutter_bridge::api::port_forward::*;
use termex_flutter_bridge::db_state;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    _test_clear_registry();
    // Seed servers that port_forwards FK needs.
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let now = chrono::Utc::now().to_rfc3339();
            for sid in &["s", "s1", "s2", "server-42"] {
                conn.execute(
                    "INSERT INTO servers
                       (id, name, host, port, username, auth_type, created_at, updated_at)
                     VALUES (?1, ?1, 'h', 22, 'u', 'password', ?2, ?2)",
                    rusqlite::params![sid, now],
                )?;
            }
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
    .unwrap();
    dir
}

#[test]
fn test_port_forward_type_str_roundtrip() {
    for t in &[ForwardType::Local, ForwardType::Remote, ForwardType::Dynamic] {
        assert_eq!(Some(*t), ForwardType::from_str(t.as_str()));
    }
    assert!(ForwardType::from_str("invalid").is_none());
}

#[test]
fn test_port_forward_conflict_detection_in_memory() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let _id = port_forward_start_ex(
        "s".into(),
        ForwardType::Local,
        "127.0.0.1".into(),
        8080,
        "web".into(),
        80,
        false,
        false,
    )
    .unwrap();

    // Same bind_ip+port → conflict.
    let err = port_forward_start_ex(
        "s2".into(),
        ForwardType::Local,
        "127.0.0.1".into(),
        8080,
        "x".into(),
        80,
        false,
        false,
    )
    .unwrap_err();
    assert!(err.contains("already bound"));
}

#[test]
fn test_port_forward_different_bind_ips_do_not_conflict() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let _ = port_forward_start_ex(
        "s1".into(),
        ForwardType::Local,
        "127.0.0.1".into(),
        8080,
        "a".into(),
        80,
        false,
        false,
    )
    .unwrap();
    let id2 = port_forward_start_ex(
        "s2".into(),
        ForwardType::Local,
        "127.0.0.2".into(),
        8080,
        "b".into(),
        80,
        false,
        false,
    )
    .unwrap();
    assert!(!id2.is_empty());
}

#[test]
fn test_port_forward_0_0_0_0_requires_allow_lan() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let err = port_forward_start_ex(
        "s".into(),
        ForwardType::Local,
        "0.0.0.0".into(),
        9999,
        "x".into(),
        80,
        false,
        false,
    )
    .unwrap_err();
    assert!(err.contains("LAN"));

    port_forward_start_ex(
        "s".into(),
        ForwardType::Local,
        "0.0.0.0".into(),
        9999,
        "x".into(),
        80,
        false,
        true,
    )
    .unwrap();
}

#[test]
fn test_port_forward_suggest_free_port_skips_occupied() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let _ = port_forward_start_ex(
        "s".into(),
        ForwardType::Local,
        "127.0.0.1".into(),
        8080,
        "x".into(),
        80,
        false,
        false,
    )
    .unwrap();
    let free = port_forward_suggest_free_port("127.0.0.1".into(), 8080, 10).unwrap();
    assert_eq!(free, Some(8081));
}

#[test]
fn test_port_forward_persists_to_db() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let id = port_forward_start_ex(
        "server-42".into(),
        ForwardType::Remote,
        "127.0.0.1".into(),
        8443,
        "internal".into(),
        443,
        true,
        false,
    )
    .unwrap();

    // Clear the in-memory registry to force the DB fallback path in list().
    _test_clear_registry();
    let list = port_forward_list("server-42".into()).unwrap();
    assert_eq!(list.len(), 1);
    assert_eq!(list[0].id, id);
    assert!(matches!(list[0].forward_type, ForwardType::Remote));
    assert_eq!(list[0].local_port, 8443);
    assert!(list[0].auto_start);
}

#[test]
fn test_port_forward_stop_removes_from_db() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let id = port_forward_start_ex(
        "s".into(),
        ForwardType::Local,
        "127.0.0.1".into(),
        7000,
        "x".into(),
        80,
        false,
        false,
    )
    .unwrap();
    port_forward_stop(id).unwrap();
    _test_clear_registry();
    let list = port_forward_list("s".into()).unwrap();
    assert!(list.is_empty());
}

#[test]
fn test_port_forward_disable_sets_inactive() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let id = port_forward_start_ex(
        "s".into(),
        ForwardType::Local,
        "127.0.0.1".into(),
        6000,
        "x".into(),
        80,
        false,
        false,
    )
    .unwrap();
    port_forward_disable(id.clone()).unwrap();

    // DB path: is_active / enabled should be false.
    _test_clear_registry();
    let list = port_forward_list("s".into()).unwrap();
    assert_eq!(list.len(), 1);
    assert!(!list[0].is_active);
}

#[test]
fn test_port_forward_status_reports_running_after_start() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let id = port_forward_start_ex(
        "s".into(),
        ForwardType::Dynamic,
        "127.0.0.1".into(),
        1080,
        "".into(),
        0,
        false,
        false,
    )
    .unwrap();
    assert!(matches!(port_forward_status(id.clone()), ForwardStatus::Running));
    port_forward_stop(id).unwrap();
}
