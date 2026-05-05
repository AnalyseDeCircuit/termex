use std::io::Write as _;
use std::sync::Mutex;

use tempfile::TempDir;
use termex_core::storage::db::Database;
use termex_flutter_bridge::api::ssh_config::*;
use termex_flutter_bridge::db_state;

/// Serialize all tests that share the global DB singleton.
static DB_LOCK: Mutex<()> = Mutex::new(());

fn setup_test_db() -> (TempDir, std::sync::MutexGuard<'static, ()>) {
    let guard = DB_LOCK.lock().unwrap();
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    (dir, guard)
}

/// Write a minimal SSH config file into `dir` and return its path string.
fn write_ssh_config(dir: &TempDir, content: &str) -> String {
    let path = dir.path().join("ssh_config");
    let mut f = std::fs::File::create(&path).unwrap();
    f.write_all(content.as_bytes()).unwrap();
    path.to_string_lossy().into_owned()
}

// ─── preview_ssh_config_import ───────────────────────────────────────────────

#[test]
fn test_preview_nonexistent_file_returns_error() {
    let (_dir, _lock) = setup_test_db();
    let result = preview_ssh_config_import(Some("/nonexistent/path/config".into()));
    assert!(result.is_err(), "expected Err for missing file, got Ok");
}

#[test]
fn test_preview_empty_config_returns_empty_list() {
    let (dir, _lock) = setup_test_db();
    let path = write_ssh_config(&dir, "");
    let entries = preview_ssh_config_import(Some(path)).unwrap();
    assert!(entries.is_empty());
}

#[test]
fn test_preview_parses_single_host() {
    let (dir, _lock) = setup_test_db();
    let config = "\
Host web-01
    HostName web-01.example.com
    User deploy
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
";
    let path = write_ssh_config(&dir, config);
    let entries = preview_ssh_config_import(Some(path)).unwrap();
    assert_eq!(entries.len(), 1);
    let e = &entries[0];
    assert_eq!(e.host_alias, "web-01");
    assert_eq!(e.hostname, "web-01.example.com");
    assert_eq!(e.port, 2222);
    assert_eq!(e.username, "deploy");
    assert!(e.identity_file.is_some());
    assert!(!e.is_wildcard);
}

#[test]
fn test_preview_skips_wildcard_host() {
    let (dir, _lock) = setup_test_db();
    let config = "\
Host *
    ServerAliveInterval 60

Host dev-01
    HostName 10.0.0.1
    User ubuntu
";
    let path = write_ssh_config(&dir, config);
    let entries = preview_ssh_config_import(Some(path)).unwrap();
    // Wildcard should not appear in results.
    assert_eq!(entries.len(), 1);
    assert_eq!(entries[0].host_alias, "dev-01");
}

#[test]
fn test_preview_multiple_hosts() {
    let (dir, _lock) = setup_test_db();
    let config = "\
Host web-01
    HostName web-01.example.com
    User deploy

Host db-prod
    HostName db.internal
    User admin
    Port 2222
";
    let path = write_ssh_config(&dir, config);
    let entries = preview_ssh_config_import(Some(path)).unwrap();
    assert_eq!(entries.len(), 2);
    assert_eq!(entries[0].host_alias, "web-01");
    assert_eq!(entries[1].host_alias, "db-prod");
    assert_eq!(entries[1].port, 2222);
}

// ─── import_ssh_config ───────────────────────────────────────────────────────

#[test]
fn test_import_empty_selection_imports_nothing() {
    let (dir, _lock) = setup_test_db();
    let config = "\
Host web-01
    HostName web-01.example.com
    User deploy
";
    let path = write_ssh_config(&dir, config);
    let result = import_ssh_config(Some(path), vec![]).unwrap();
    assert_eq!(result.imported, 0);
}

#[test]
fn test_import_selected_host_creates_server() {
    let (dir, _lock) = setup_test_db();
    let config = "\
Host web-01
    HostName web-01.example.com
    User deploy
    Port 22

Host db-prod
    HostName db.internal
    User admin
    Port 5432
";
    let path = write_ssh_config(&dir, config);
    let result =
        import_ssh_config(Some(path), vec!["web-01".into()]).unwrap();
    assert_eq!(result.imported, 1);
    assert_eq!(result.skipped, 1); // db-prod was not selected

    // Verify server actually exists in DB.
    let servers = termex_flutter_bridge::api::server::list_servers().unwrap();
    assert_eq!(servers.len(), 1);
    assert_eq!(servers[0].host, "web-01.example.com");
    assert_eq!(servers[0].username, "deploy");
}

#[test]
fn test_import_duplicate_skipped() {
    let (dir, _lock) = setup_test_db();
    let config = "\
Host web-01
    HostName web-01.example.com
    User deploy
    Port 22
";
    let path = write_ssh_config(&dir, config);

    // First import — should succeed.
    let r1 = import_ssh_config(Some(path.clone()), vec!["web-01".into()]).unwrap();
    assert_eq!(r1.imported, 1);

    // Second import of the same entry — should be detected as duplicate.
    let r2 = import_ssh_config(Some(path), vec!["web-01".into()]).unwrap();
    assert_eq!(r2.imported, 0);
    assert_eq!(r2.skipped, 1);
}

#[test]
fn test_import_key_auth_type_assigned() {
    let (dir, _lock) = setup_test_db();
    let config = "\
Host dev-box
    HostName 10.0.0.5
    User dev
    IdentityFile ~/.ssh/id_rsa
";
    let path = write_ssh_config(&dir, config);
    import_ssh_config(Some(path), vec!["dev-box".into()]).unwrap();

    let servers = termex_flutter_bridge::api::server::list_servers().unwrap();
    assert_eq!(servers.len(), 1);
    // When IdentityFile is set the server should use key auth.
    assert_eq!(
        format!("{:?}", servers[0].auth_type),
        "Key",
        "expected Key auth type for entry with IdentityFile"
    );
}
