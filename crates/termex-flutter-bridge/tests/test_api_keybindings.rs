use std::sync::{Mutex, MutexGuard};

use termex_flutter_bridge::api::keybindings::*;

/// Serialises tests that touch the global keybinding registry.
static KB_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> MutexGuard<'static, ()> {
    let guard = KB_LOCK.lock().unwrap();
    _test_clear_registry();
    guard
}

// ─── Defaults ────────────────────────────────────────────────────────────────

#[test]
fn test_keybinding_get_defaults_not_empty() {
    let defaults = keybinding_get_defaults();
    assert!(!defaults.is_empty(), "should have at least one default keybinding");
    assert!(defaults.len() >= 15, "expected at least 15 defaults");
}

#[test]
fn test_keybinding_get_defaults_new_tab() {
    let defaults = keybinding_get_defaults();
    let new_tab = defaults.iter().find(|e| e.action == "new_tab");
    assert!(new_tab.is_some(), "new_tab should be in defaults");
    assert_eq!(new_tab.unwrap().key_combination, "⌘T");
}

#[test]
fn test_keybinding_get_defaults_all_have_context() {
    for entry in keybinding_get_defaults() {
        assert!(
            matches!(entry.context.as_str(), "global" | "terminal" | "sftp"),
            "unexpected context '{}' for action '{}'",
            entry.context,
            entry.action
        );
    }
}

// ─── List ────────────────────────────────────────────────────────────────────

#[test]
fn test_keybinding_list_returns_defaults_when_no_overrides() {
    let _guard = setup();
    let list = keybinding_list().unwrap();
    let defaults = keybinding_get_defaults();
    // Every default action should appear in list.
    for def in &defaults {
        assert!(
            list.iter().any(|e| e.action == def.action),
            "action '{}' missing from list",
            def.action
        );
    }
}

// ─── Set ─────────────────────────────────────────────────────────────────────

#[test]
fn test_keybinding_set_and_list() {
    let _guard = setup();
    keybinding_set("new_tab".into(), "Ctrl+T".into(), "global".into()).unwrap();
    let list = keybinding_list().unwrap();
    let entry = list.iter().find(|e| e.action == "new_tab").unwrap();
    assert_eq!(entry.key_combination, "Ctrl+T");
}

#[test]
fn test_keybinding_set_custom_action() {
    let _guard = setup();
    keybinding_set("my_custom".into(), "⌘Shift+X".into(), "terminal".into()).unwrap();
    let list = keybinding_list().unwrap();
    assert!(list.iter().any(|e| e.action == "my_custom"));
}

// ─── Reset ───────────────────────────────────────────────────────────────────

#[test]
fn test_keybinding_reset_restores_default() {
    let _guard = setup();
    keybinding_set("new_tab".into(), "Ctrl+T".into(), "global".into()).unwrap();
    keybinding_reset("new_tab".into()).unwrap();
    let list = keybinding_list().unwrap();
    let entry = list.iter().find(|e| e.action == "new_tab").unwrap();
    // After reset, default should be restored.
    let default_combo = keybinding_get_defaults()
        .into_iter()
        .find(|e| e.action == "new_tab")
        .unwrap()
        .key_combination;
    assert_eq!(entry.key_combination, default_combo);
}

#[test]
fn test_keybinding_reset_all_ok() {
    let _guard = setup();
    keybinding_set("close_tab".into(), "Ctrl+W".into(), "global".into()).unwrap();
    keybinding_reset_all().unwrap();
    // After reset_all, list should return default combination for close_tab.
    let list = keybinding_list().unwrap();
    let entry = list.iter().find(|e| e.action == "close_tab").unwrap();
    let default_combo = keybinding_get_defaults()
        .into_iter()
        .find(|e| e.action == "close_tab")
        .unwrap()
        .key_combination;
    assert_eq!(entry.key_combination, default_combo);
}

// ─── Conflict detection ───────────────────────────────────────────────────────

#[test]
fn test_keybinding_check_conflict_detects_existing() {
    // "⌘T" is already used by "new_tab" (global) — checks defaults only, no registry needed.
    let conflict = keybinding_check_conflict("⌘T".into(), "global".into()).unwrap();
    assert!(conflict.is_some(), "⌘T should conflict with new_tab");
    let info = conflict.unwrap();
    assert_eq!(info.action, "new_tab");
}

#[test]
fn test_keybinding_check_conflict_no_conflict() {
    // An unmapped combination should not conflict.
    let conflict = keybinding_check_conflict("⌘Shift+Z".into(), "global".into()).unwrap();
    assert!(conflict.is_none(), "⌘Shift+Z should not conflict");
}

#[test]
fn test_keybinding_check_conflict_terminal_vs_global() {
    // "⌘T" is global, so it should conflict even when checking terminal context.
    let conflict = keybinding_check_conflict("⌘T".into(), "terminal".into()).unwrap();
    assert!(conflict.is_some(), "global binding should conflict in terminal context");
}
