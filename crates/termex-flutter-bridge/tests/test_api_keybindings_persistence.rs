//! v0.46 keybinding persistence tests: verify V22 keybindings table is used
//! when the database is unlocked.

use std::sync::Mutex;
use tempfile::TempDir;

use termex_core::storage::db::Database;
use termex_flutter_bridge::api::keybindings::*;
use termex_flutter_bridge::db_state;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    _test_clear_registry();
    // Ensure the DB table is empty.
    let _ = keybinding_reset_all();
    dir
}

#[test]
fn test_keybinding_set_survives_reload() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    keybinding_set("new_tab".into(), "Ctrl+Alt+N".into(), "global".into()).unwrap();

    let list = keybinding_list().unwrap();
    let entry = list.iter().find(|e| e.action == "new_tab").unwrap();
    assert_eq!(entry.key_combination, "Ctrl+Alt+N");
}

#[test]
fn test_keybinding_reset_removes_database_row() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    keybinding_set("new_tab".into(), "Ctrl+Alt+N".into(), "global".into()).unwrap();
    keybinding_reset("new_tab".into()).unwrap();

    let list = keybinding_list().unwrap();
    let entry = list.iter().find(|e| e.action == "new_tab").unwrap();
    // Default must be restored.
    assert_eq!(entry.key_combination, "⌘T");
}

#[test]
fn test_keybinding_reset_all_clears_table() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    keybinding_set("close_tab".into(), "Ctrl+X".into(), "global".into()).unwrap();
    keybinding_set("new_tab".into(), "Ctrl+Y".into(), "global".into()).unwrap();
    keybinding_reset_all().unwrap();

    let list = keybinding_list().unwrap();
    // All defaults restored.
    for e in &list {
        let default = keybinding_get_defaults()
            .into_iter()
            .find(|d| d.action == e.action)
            .unwrap();
        assert_eq!(e.key_combination, default.key_combination);
    }
}

#[test]
fn test_keybinding_check_conflict_sees_database_overrides() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    keybinding_set("custom_action".into(), "Ctrl+Shift+X".into(), "global".into())
        .unwrap();

    let conflict =
        keybinding_check_conflict("Ctrl+Shift+X".into(), "terminal".into()).unwrap();
    assert!(conflict.is_some(), "override should surface as conflict");
    assert_eq!(conflict.unwrap().action, "custom_action");
}
