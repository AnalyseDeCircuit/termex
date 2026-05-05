use tempfile::TempDir;
use termex_core::storage::db::Database;
use termex_flutter_bridge::{db_state, api::ssh::*};

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    dir
}

#[test]
fn test_check_host_key_new_host() {
    let _dir = setup();
    let result = check_host_key(
        "example.com".into(),
        22,
        "SHA256:abcdef".into(),
        "ecdsa-sha2-nistp256".into(),
    )
    .unwrap();
    assert_eq!(result, "new:SHA256:abcdef");
}

#[test]
fn test_trust_and_check_trusted() {
    let _dir = setup();
    trust_host_key(
        "example.com".into(),
        22,
        "SHA256:abcdef".into(),
        "ecdsa-sha2-nistp256".into(),
    )
    .unwrap();
    let result = check_host_key(
        "example.com".into(),
        22,
        "SHA256:abcdef".into(),
        "ecdsa-sha2-nistp256".into(),
    )
    .unwrap();
    assert_eq!(result, "trusted");
}

#[test]
fn test_key_changed() {
    let _dir = setup();
    trust_host_key(
        "example.com".into(),
        22,
        "SHA256:oldkey".into(),
        "ecdsa-sha2-nistp256".into(),
    )
    .unwrap();
    let result = check_host_key(
        "example.com".into(),
        22,
        "SHA256:newkey".into(),
        "ecdsa-sha2-nistp256".into(),
    )
    .unwrap();
    assert!(result.starts_with("changed:SHA256:oldkey:"));
}

#[test]
fn test_check_agent_available_no_socket() {
    // Remove SSH_AUTH_SOCK so agent is unavailable
    std::env::remove_var("SSH_AUTH_SOCK");
    let available = check_ssh_agent_available().unwrap();
    assert!(!available);
}
