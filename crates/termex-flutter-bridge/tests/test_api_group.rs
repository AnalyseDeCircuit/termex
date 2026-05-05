use std::sync::Mutex;
use tempfile::TempDir;
use termex_core::storage::db::Database;
use termex_flutter_bridge::{db_state, api::group::*};

// Serialize all tests in this file to avoid global DB state conflicts.
static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    dir
}

#[test]
fn test_list_groups_empty() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let groups = list_groups().unwrap();
    assert!(groups.is_empty());
}

#[test]
fn test_create_and_delete_group() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let input = GroupInput {
        name: "Production".into(),
        color: "#FF0000".into(),
        icon: "server".into(),
        parent_id: None,
        sort_order: 0,
    };
    let created = create_group(input).unwrap();
    assert_eq!(created.name, "Production");

    delete_group(created.id.clone()).unwrap();
    let groups = list_groups().unwrap();
    assert!(groups.is_empty());
}

#[test]
fn test_reorder_groups() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let g1 = create_group(GroupInput {
        name: "G1".into(),
        color: "#000".into(),
        icon: "s".into(),
        parent_id: None,
        sort_order: 0,
    })
    .unwrap();
    let g2 = create_group(GroupInput {
        name: "G2".into(),
        color: "#000".into(),
        icon: "s".into(),
        parent_id: None,
        sort_order: 1,
    })
    .unwrap();

    // Reverse order
    reorder_groups(vec![g2.id.clone(), g1.id.clone()]).unwrap();

    let groups = list_groups().unwrap();
    assert_eq!(groups[0].id, g2.id);
    assert_eq!(groups[1].id, g1.id);
}

#[test]
fn test_get_group_not_found() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let result = get_group("nonexistent-id".into()).unwrap();
    assert!(result.is_none());
}

#[test]
fn test_update_group() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let created = create_group(GroupInput {
        name: "Original".into(),
        color: "#000".into(),
        icon: "folder".into(),
        parent_id: None,
        sort_order: 0,
    })
    .unwrap();

    let updated = update_group(
        created.id.clone(),
        GroupInput {
            name: "Updated".into(),
            color: "#FFF".into(),
            icon: "server".into(),
            parent_id: None,
            sort_order: 5,
        },
    )
    .unwrap();

    assert_eq!(updated.name, "Updated");
    assert_eq!(updated.color, "#FFF");
    assert_eq!(updated.sort_order, 5);
}
