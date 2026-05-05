/// Tests for plugin.rs (FRB plugin management bridge).
use std::sync::Mutex;

use termex_flutter_bridge::api::plugin::*;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> std::sync::MutexGuard<'static, ()> {
    let guard = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    _test_clear_plugins();
    guard
}

fn minimal_manifest(id: &str) -> String {
    serde_json::json!({
        "id": id,
        "name": format!("{} Plugin", id),
        "version": "1.0.0",
        "description": "A test plugin",
        "entry": "index.js",
        "permissions": ["terminal_read", "network"]
    })
    .to_string()
}

// ─── List / Register ──────────────────────────────────────────────────────────

#[test]
fn test_plugin_list_empty_initially() {
    let _lock = setup();
    assert!(plugin_list().is_empty());
}

#[test]
fn test_plugin_register_returns_dto() {
    let _lock = setup();
    let dto = plugin_register(minimal_manifest("echo"), "/plugins/echo".to_string()).unwrap();
    assert_eq!(dto.id, "echo");
    assert_eq!(dto.version, "1.0.0");
    assert_eq!(dto.state, "enabled");
}

#[test]
fn test_plugin_register_duplicate_returns_error() {
    let _lock = setup();
    plugin_register(minimal_manifest("dup"), "/p/dup".to_string()).unwrap();
    let err = plugin_register(minimal_manifest("dup"), "/p/dup".to_string());
    assert!(err.is_err());
    assert!(err.unwrap_err().contains("already installed"));
}

#[test]
fn test_plugin_list_after_register() {
    let _lock = setup();
    plugin_register(minimal_manifest("a"), "/p/a".to_string()).unwrap();
    plugin_register(minimal_manifest("b"), "/p/b".to_string()).unwrap();
    assert_eq!(plugin_list().len(), 2);
}

// ─── Uninstall ────────────────────────────────────────────────────────────────

#[test]
fn test_plugin_uninstall_removes_entry() {
    let _lock = setup();
    plugin_register(minimal_manifest("rm-me"), "/p/rm".to_string()).unwrap();
    plugin_uninstall("rm-me".to_string()).unwrap();
    assert!(plugin_list().is_empty());
}

#[test]
fn test_plugin_uninstall_missing_returns_error() {
    let _lock = setup();
    let err = plugin_uninstall("ghost".to_string());
    assert!(err.is_err());
}

// ─── Enable / Disable ─────────────────────────────────────────────────────────

#[test]
fn test_plugin_enable_disable_toggles_state() {
    let _lock = setup();
    plugin_register(minimal_manifest("tog"), "/p/tog".to_string()).unwrap();

    plugin_disable("tog".to_string()).unwrap();
    let dto = plugin_list().into_iter().find(|d| d.id == "tog").unwrap();
    assert_eq!(dto.state, "disabled");

    plugin_enable("tog".to_string()).unwrap();
    let dto = plugin_list().into_iter().find(|d| d.id == "tog").unwrap();
    assert_eq!(dto.state, "enabled");
}

// ─── Permissions ─────────────────────────────────────────────────────────────

#[test]
fn test_grant_declared_permission_succeeds() {
    let _lock = setup();
    plugin_register(minimal_manifest("perm"), "/p/perm".to_string()).unwrap();
    plugin_grant_permission("perm".to_string(), "network".to_string()).unwrap();

    let result = plugin_check_permission("perm".to_string(), "network".to_string());
    assert!(result.granted);
}

#[test]
fn test_grant_undeclared_permission_fails() {
    let _lock = setup();
    plugin_register(minimal_manifest("perm2"), "/p/perm2".to_string()).unwrap();
    let err = plugin_grant_permission("perm2".to_string(), "clipboard".to_string());
    assert!(err.is_err());
    assert!(err.unwrap_err().contains("not declared"));
}

#[test]
fn test_revoke_permission() {
    let _lock = setup();
    plugin_register(minimal_manifest("rev"), "/p/rev".to_string()).unwrap();
    plugin_grant_permission("rev".to_string(), "terminal_read".to_string()).unwrap();
    plugin_revoke_permission("rev".to_string(), "terminal_read".to_string()).unwrap();

    let result = plugin_check_permission("rev".to_string(), "terminal_read".to_string());
    assert!(!result.granted);
}

#[test]
fn test_granted_permissions_appear_in_dto() {
    let _lock = setup();
    plugin_register(minimal_manifest("gp"), "/p/gp".to_string()).unwrap();
    plugin_grant_permission("gp".to_string(), "terminal_read".to_string()).unwrap();
    plugin_grant_permission("gp".to_string(), "network".to_string()).unwrap();

    let dto = plugin_list().into_iter().find(|d| d.id == "gp").unwrap();
    assert!(dto.granted_permissions.contains(&"terminal_read".to_string()));
    assert!(dto.granted_permissions.contains(&"network".to_string()));
}

// ─── Developer mode ───────────────────────────────────────────────────────────

#[test]
fn test_developer_mode_off_by_default() {
    let _lock = setup();
    assert!(!plugin_developer_mode());
}

#[test]
fn test_developer_mode_toggle() {
    let _lock = setup();
    plugin_set_developer_mode(true);
    assert!(plugin_developer_mode());
    plugin_set_developer_mode(false);
    assert!(!plugin_developer_mode());
}

// ─── Permissions after uninstall ─────────────────────────────────────────────

#[test]
fn test_uninstall_clears_grants() {
    let _lock = setup();
    plugin_register(minimal_manifest("cleanup"), "/p/cleanup".to_string()).unwrap();
    plugin_grant_permission("cleanup".to_string(), "terminal_read".to_string()).unwrap();
    plugin_uninstall("cleanup".to_string()).unwrap();

    let result = plugin_check_permission("cleanup".to_string(), "terminal_read".to_string());
    assert!(!result.granted);
}
