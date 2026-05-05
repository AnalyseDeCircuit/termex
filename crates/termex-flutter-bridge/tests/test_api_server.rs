use std::sync::Mutex;
use tempfile::TempDir;
use termex_core::storage::db::Database;
use termex_flutter_bridge::api::server::*;
use termex_flutter_bridge::db_state;

/// Serialize all tests that mutate the global DB singleton.
static DB_LOCK: Mutex<()> = Mutex::new(());

fn setup_test_db() -> (TempDir, std::sync::MutexGuard<'static, ()>) {
    let guard = DB_LOCK.lock().unwrap();
    let dir = TempDir::new().unwrap();
    let db_path = dir.path().join("test.db");
    let db = Database::open_at(db_path, None).unwrap();
    db_state::init_for_test(db);
    (dir, guard)
}

#[test]
fn test_list_servers_empty() {
    let (_dir, _lock) = setup_test_db();
    let servers = list_servers().unwrap();
    assert!(servers.is_empty());
}

#[test]
fn test_create_and_get_server() {
    let (_dir, _lock) = setup_test_db();
    let input = ServerInput {
        name: "Test Server".into(),
        host: "example.com".into(),
        port: 22,
        username: "user".into(),
        auth_type: AuthType::Password,
        password: Some("secret".into()),
        key_path: None,
        group_id: None,
        tags: vec![],
    };
    let created = create_server(input).unwrap();
    assert_eq!(created.name, "Test Server");
    assert_eq!(created.host, "example.com");

    let fetched = get_server(created.id.clone()).unwrap();
    assert!(fetched.is_some());
    assert_eq!(fetched.unwrap().id, created.id);
}

#[test]
fn test_update_server() {
    let (_dir, _lock) = setup_test_db();
    let input = ServerInput {
        name: "Original".into(),
        host: "host.com".into(),
        port: 22,
        username: "user".into(),
        auth_type: AuthType::Password,
        password: None,
        key_path: None,
        group_id: None,
        tags: vec!["prod".into()],
    };
    let created = create_server(input).unwrap();

    let update = ServerInput {
        name: "Updated".into(),
        host: "newhost.com".into(),
        port: 2222,
        username: "admin".into(),
        auth_type: AuthType::Key,
        password: None,
        key_path: Some("/path/to/key".into()),
        group_id: None,
        tags: vec!["prod".into(), "updated".into()],
    };
    let updated = update_server(created.id.clone(), update).unwrap();
    assert_eq!(updated.name, "Updated");
    assert_eq!(updated.port, 2222);
}

#[test]
fn test_delete_server() {
    let (_dir, _lock) = setup_test_db();
    let input = ServerInput {
        name: "ToDelete".into(),
        host: "host.com".into(),
        port: 22,
        username: "user".into(),
        auth_type: AuthType::Key,
        password: None,
        key_path: None,
        group_id: None,
        tags: vec![],
    };
    let created = create_server(input).unwrap();
    delete_server(created.id.clone()).unwrap();
    let fetched = get_server(created.id).unwrap();
    assert!(fetched.is_none());
}

#[test]
fn test_update_last_connected() {
    let (_dir, _lock) = setup_test_db();
    let input = ServerInput {
        name: "Server".into(),
        host: "host.com".into(),
        port: 22,
        username: "user".into(),
        auth_type: AuthType::Password,
        password: None,
        key_path: None,
        group_id: None,
        tags: vec![],
    };
    let created = create_server(input).unwrap();
    assert!(created.last_connected.is_none());

    update_last_connected(created.id.clone()).unwrap();
    let updated = get_server(created.id).unwrap().unwrap();
    assert!(updated.last_connected.is_some());
}

#[test]
fn test_quick_connect_history() {
    let (_dir, _lock) = setup_test_db();

    add_quick_connect_history("example.com".into(), 22, "user".into()).unwrap();
    add_quick_connect_history("other.com".into(), 2222, "admin".into()).unwrap();

    let history = list_quick_connect_history().unwrap();
    assert_eq!(history.len(), 2);

    clear_quick_connect_history().unwrap();
    let empty = list_quick_connect_history().unwrap();
    assert!(empty.is_empty());
}
