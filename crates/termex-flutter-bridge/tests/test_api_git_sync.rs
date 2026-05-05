//! v0.47 Git Sync API tests (§7).

use std::sync::Mutex;
use tempfile::TempDir;

use termex_core::storage::db::Database;
use termex_flutter_bridge::api::git_sync::*;
use termex_flutter_bridge::db_state;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    // Seed one row in `servers` so git_sync_enable can update it.
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let now = chrono::Utc::now().to_rfc3339();
            conn.execute(
                "INSERT INTO servers
                   (id, name, host, port, username, auth_type, created_at, updated_at)
                 VALUES ('srv-1', 'test', 'localhost', 22, 'me', 'password', ?1, ?1)",
                rusqlite::params![now],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
    .unwrap();
    dir
}

// ─── Mode / Health enums ────────────────────────────────────────────────────

#[test]
fn test_git_sync_mode_roundtrip() {
    assert_eq!(GitSyncMode::from_str("notify"), GitSyncMode::Notify);
    assert_eq!(GitSyncMode::from_str("auto"), GitSyncMode::Auto);
    assert_eq!(GitSyncMode::from_str("manual"), GitSyncMode::Manual);
    assert_eq!(GitSyncMode::from_str("invalid"), GitSyncMode::Notify);
    assert_eq!(GitSyncMode::Notify.as_str(), "notify");
    assert_eq!(GitSyncMode::Auto.as_str(), "auto");
    assert_eq!(GitSyncMode::Manual.as_str(), "manual");
}

// ─── Single-repo ────────────────────────────────────────────────────────────

#[test]
fn test_git_sync_status_disabled_by_default() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let status = git_sync_status("srv-1".into()).unwrap();
    assert!(!status.enabled);
    assert_eq!(status.health, GitSyncHealth::Disabled);
}

#[test]
fn test_git_sync_status_unknown_server_returns_disabled() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let status = git_sync_status("does-not-exist".into()).unwrap();
    assert!(!status.enabled);
    assert_eq!(status.health, GitSyncHealth::Disabled);
}

#[test]
fn test_git_sync_enable_flips_flag() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    git_sync_enable(
        "srv-1".into(),
        "git@github.com:org/repo.git".into(),
        "/Users/me/repo".into(),
    )
    .unwrap();

    let status = git_sync_status("srv-1".into()).unwrap();
    assert!(status.enabled);
    assert_eq!(status.health, GitSyncHealth::Synced);
    assert_eq!(status.remote_url, "git@github.com:org/repo.git");
    assert_eq!(status.local_path, "/Users/me/repo");
}

#[test]
fn test_git_sync_disable_reverts_status() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    git_sync_enable(
        "srv-1".into(),
        "git@example.com:r.git".into(),
        "/tmp/r".into(),
    )
    .unwrap();
    git_sync_disable("srv-1".into()).unwrap();

    let status = git_sync_status("srv-1".into()).unwrap();
    assert!(!status.enabled);
    assert_eq!(status.health, GitSyncHealth::Disabled);
}

#[test]
fn test_git_sync_trigger_is_audited() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    git_sync_enable("srv-1".into(), "r".into(), "/tmp/r".into()).unwrap();
    let status = git_sync_trigger("srv-1".into()).unwrap();
    assert!(status.enabled);
}

// ─── Multi-repo (V23 table) ─────────────────────────────────────────────────

#[test]
fn test_git_sync_add_repo_persists() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let id = git_sync_add_repo(GitSyncInput {
        server_id: "srv-1".into(),
        local_path: "/tmp/r1".into(),
        remote_url: "git@host:r1.git".into(),
        sync_mode: GitSyncMode::Auto,
    })
    .unwrap();
    assert!(!id.is_empty());

    let repos = git_sync_list_repos("srv-1".into()).unwrap();
    assert_eq!(repos.len(), 1);
    assert_eq!(repos[0].id, id);
    assert_eq!(repos[0].sync_mode, GitSyncMode::Auto);
    assert_eq!(repos[0].local_path, "/tmp/r1");
}

#[test]
fn test_git_sync_multiple_repos_per_server() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    for i in 0..3 {
        git_sync_add_repo(GitSyncInput {
            server_id: "srv-1".into(),
            local_path: format!("/tmp/r{i}"),
            remote_url: format!("git@host:r{i}.git"),
            sync_mode: GitSyncMode::Notify,
        })
        .unwrap();
    }
    assert_eq!(git_sync_list_repos("srv-1".into()).unwrap().len(), 3);
}

#[test]
fn test_git_sync_remove_repo_deletes_row() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let id = git_sync_add_repo(GitSyncInput {
        server_id: "srv-1".into(),
        local_path: "/tmp/r".into(),
        remote_url: "r".into(),
        sync_mode: GitSyncMode::Notify,
    })
    .unwrap();
    assert_eq!(git_sync_list_repos("srv-1".into()).unwrap().len(), 1);

    git_sync_remove_repo(id).unwrap();
    assert!(git_sync_list_repos("srv-1".into()).unwrap().is_empty());
}

#[test]
fn test_git_sync_update_repo_mode() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let id = git_sync_add_repo(GitSyncInput {
        server_id: "srv-1".into(),
        local_path: "/tmp/r".into(),
        remote_url: "r".into(),
        sync_mode: GitSyncMode::Notify,
    })
    .unwrap();

    git_sync_update_repo_mode(id.clone(), GitSyncMode::Auto).unwrap();
    let repos = git_sync_list_repos("srv-1".into()).unwrap();
    assert_eq!(repos[0].sync_mode, GitSyncMode::Auto);
}

#[test]
fn test_git_sync_record_sync_result_updates_timestamps() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let id = git_sync_add_repo(GitSyncInput {
        server_id: "srv-1".into(),
        local_path: "/tmp/r".into(),
        remote_url: "r".into(),
        sync_mode: GitSyncMode::Auto,
    })
    .unwrap();

    git_sync_record_sync_result(id.clone(), None).unwrap();
    let repos = git_sync_list_repos("srv-1".into()).unwrap();
    assert!(repos[0].last_sync_at.is_some());
    assert!(repos[0].last_error.is_none());

    git_sync_record_sync_result(id, Some("network timeout".into())).unwrap();
    let repos = git_sync_list_repos("srv-1".into()).unwrap();
    assert_eq!(repos[0].last_error.as_deref(), Some("network timeout"));
}
