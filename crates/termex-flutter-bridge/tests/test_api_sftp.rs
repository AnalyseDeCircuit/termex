use std::sync::Mutex;

use tempfile::TempDir;
use termex_core::storage::db::Database;
use termex_flutter_bridge::api::sftp::*;
use termex_flutter_bridge::db_state;

static DB_LOCK: Mutex<()> = Mutex::new(());

fn setup_test_db() -> (TempDir, std::sync::MutexGuard<'static, ()>) {
    let guard = DB_LOCK.lock().unwrap();
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    (dir, guard)
}

// ─── Error paths (no real SSH session) ───────────────────────────────────────
//
// These tests verify that the bridge surfaces a useful error when a caller
// asks for SFTP operations against a session that was never opened. Real
// round-trip tests require a russh server and live in the Flutter
// integration suite.

#[tokio::test]
async fn open_sftp_channel_rejects_unknown_session() {
    let (_dir, _lock) = setup_test_db();
    let result = open_sftp_channel("no-such-session".into()).await;
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("SSH session not found"));
}

#[tokio::test]
async fn sftp_list_rejects_unknown_session() {
    let (_dir, _lock) = setup_test_db();
    let result = sftp_list("no-such-session".into(), "/".into()).await;
    assert!(result.is_err());
}

#[tokio::test]
async fn sftp_mkdir_rejects_unknown_session() {
    let (_dir, _lock) = setup_test_db();
    let result = sftp_mkdir("no-such-session".into(), "/tmp/newdir".into()).await;
    assert!(result.is_err());
}

#[tokio::test]
async fn sftp_download_rejects_unknown_session() {
    let (_dir, _lock) = setup_test_db();
    let result = sftp_download(
        "no-such-session".into(),
        "/remote/file".into(),
        "/local/file".into(),
        "xfer-1".into(),
    )
    .await;
    assert!(result.is_err());
}

#[tokio::test]
async fn sftp_upload_rejects_unknown_session() {
    let (_dir, _lock) = setup_test_db();
    let result = sftp_upload(
        "no-such-session".into(),
        "/local/file".into(),
        "/remote/file".into(),
        "xfer-2".into(),
    )
    .await;
    assert!(result.is_err());
}

#[tokio::test]
async fn is_sftp_open_false_before_open() {
    let (_dir, _lock) = setup_test_db();
    assert!(!is_sftp_open("never-opened".into()).await);
}

#[test]
fn sftp_cancel_transfer_is_noop() {
    sftp_cancel_transfer("nonexistent-transfer".into()).unwrap();
}

#[test]
fn poll_sftp_progress_returns_empty_for_unknown_transfer() {
    let events = poll_sftp_progress("never-registered".into());
    assert!(events.is_empty());
}

// ─── command_history ─────────────────────────────────────────────────────────

#[test]
fn test_record_and_list_command_history() {
    let (_dir, _lock) = setup_test_db();

    let server_id = termex_flutter_bridge::api::server::create_server(
        termex_flutter_bridge::api::server::ServerInput {
            name: "test-server".into(),
            host: "10.0.0.1".into(),
            port: 22,
            username: "user".into(),
            auth_type: termex_flutter_bridge::api::server::AuthType::Password,
            password: None,
            key_path: None,
            group_id: None,
            tags: vec![],
        },
    )
    .unwrap()
    .id;

    record_command(
        "sess-1".into(),
        Some(server_id.clone()),
        "ls -la".into(),
        Some(0),
        "2024-01-01T00:00:00Z".into(),
        Some(42),
    )
    .unwrap();

    record_command(
        "sess-1".into(),
        Some(server_id.clone()),
        "git status".into(),
        Some(0),
        "2024-01-01T00:01:00Z".into(),
        None,
    )
    .unwrap();

    let history = list_command_history(server_id.clone(), 10).unwrap();
    assert_eq!(history.len(), 2);
    assert_eq!(history[0].command, "git status");
    assert_eq!(history[1].command, "ls -la");
    assert_eq!(history[1].duration_ms, Some(42));
}

#[test]
fn test_clear_command_history() {
    let (_dir, _lock) = setup_test_db();

    let server_id = termex_flutter_bridge::api::server::create_server(
        termex_flutter_bridge::api::server::ServerInput {
            name: "server-clear".into(),
            host: "10.0.0.2".into(),
            port: 22,
            username: "user".into(),
            auth_type: termex_flutter_bridge::api::server::AuthType::Password,
            password: None,
            key_path: None,
            group_id: None,
            tags: vec![],
        },
    )
    .unwrap()
    .id;

    record_command(
        "sess-2".into(),
        Some(server_id.clone()),
        "pwd".into(),
        Some(0),
        "2024-01-02T00:00:00Z".into(),
        Some(5),
    )
    .unwrap();

    clear_command_history(server_id.clone()).unwrap();
    let history = list_command_history(server_id, 10).unwrap();
    assert!(history.is_empty());
}

#[test]
fn test_list_command_history_respects_limit() {
    let (_dir, _lock) = setup_test_db();

    let server_id = termex_flutter_bridge::api::server::create_server(
        termex_flutter_bridge::api::server::ServerInput {
            name: "server-limit".into(),
            host: "10.0.0.3".into(),
            port: 22,
            username: "user".into(),
            auth_type: termex_flutter_bridge::api::server::AuthType::Password,
            password: None,
            key_path: None,
            group_id: None,
            tags: vec![],
        },
    )
    .unwrap()
    .id;

    for i in 0..5 {
        record_command(
            "sess-3".into(),
            Some(server_id.clone()),
            format!("cmd-{i}"),
            Some(0),
            format!("2024-01-0{i}T00:00:00Z"),
            None,
        )
        .unwrap();
    }

    let history = list_command_history(server_id, 3).unwrap();
    assert_eq!(history.len(), 3);
}
