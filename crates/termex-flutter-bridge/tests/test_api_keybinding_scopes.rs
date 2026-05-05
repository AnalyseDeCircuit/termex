//! Tests for the v0.46 keybinding scope system + reserved-key blacklist (§4.4.5).

use std::sync::{Mutex, MutexGuard};

use termex_flutter_bridge::api::keybindings::*;

static KB_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> MutexGuard<'static, ()> {
    let guard = KB_LOCK.lock().unwrap();
    _test_clear_registry();
    guard
}

#[test]
fn test_five_scopes_defined() {
    let scopes = keybinding_list_scopes();
    assert_eq!(scopes.len(), 5, "spec §4.4.5 defines 5 scopes");
    for expected in &["global", "terminal", "sftp", "ai_panel", "monitor"] {
        assert!(scopes.contains(&expected.to_string()), "missing scope '{}'", expected);
    }
}

#[test]
fn test_keybinding_is_valid_scope() {
    assert!(keybinding_is_valid_scope("global"));
    assert!(keybinding_is_valid_scope("terminal"));
    assert!(keybinding_is_valid_scope("ai_panel"));
    assert!(keybinding_is_valid_scope("monitor"));
    assert!(!keybinding_is_valid_scope("nonexistent"));
    assert!(!keybinding_is_valid_scope(""));
}

#[test]
fn test_reserved_keys_include_os_shortcuts() {
    let reserved = keybinding_list_reserved_keys();
    assert!(reserved.contains(&"⌘Tab".into()));
    assert!(reserved.contains(&"⌘Space".into()));
    assert!(reserved.contains(&"Alt+F4".into()));
    assert!(reserved.contains(&"Ctrl+Alt+Del".into()));
}

#[test]
fn test_keybinding_is_reserved() {
    assert!(keybinding_is_reserved("⌘Q"));
    assert!(!keybinding_is_reserved("⌘T")); // Termex binds this.
}

#[test]
fn test_set_validated_rejects_reserved_key() {
    let _guard = setup();
    let err = keybinding_set_validated(
        "my_action".into(),
        "⌘Space".into(),
        "global".into(),
    )
    .unwrap_err();
    assert!(err.contains("reserved"));
}

#[test]
fn test_set_validated_rejects_unknown_scope() {
    let _guard = setup();
    let err = keybinding_set_validated(
        "act".into(),
        "Ctrl+Shift+X".into(),
        "not_a_scope".into(),
    )
    .unwrap_err();
    assert!(err.contains("Unknown scope"));
}

#[test]
fn test_set_validated_accepts_valid_combo() {
    let _guard = setup();
    keybinding_set_validated("my_custom".into(), "Ctrl+Shift+Y".into(), "ai_panel".into())
        .expect("valid combination should be accepted");
    let list = keybinding_list().unwrap();
    let entry = list.iter().find(|e| e.action == "my_custom").unwrap();
    assert_eq!(entry.context, "ai_panel");
}
