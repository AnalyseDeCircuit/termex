//! Tests for v0.52 gap-coverage team CRUD wiring.

use std::sync::Mutex;
use tempfile::TempDir;
use termex_core::storage::db::Database;
use termex_flutter_bridge::api::team::*;
use termex_flutter_bridge::db_state;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    dir
}

#[test]
fn team_members_crud_round_trip() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    // Empty on fresh db
    let initial = team_get_members().unwrap();
    assert!(initial.is_empty(), "fresh DB should have no members");

    // Add owner
    let owner = team_add_member(
        "Alice".into(),
        "alice@example.com".into(),
        TeamRole::Owner,
    )
    .unwrap();
    assert_eq!(owner.role, TeamRole::Owner);

    // Add member
    let bob = team_add_member("Bob".into(), "bob@example.com".into(), TeamRole::Member).unwrap();

    let list = team_get_members().unwrap();
    assert_eq!(list.len(), 2);

    // Update bob to admin
    team_update_role(bob.id.clone(), TeamRole::Admin).unwrap();
    let updated = team_get_members().unwrap();
    let bob_refreshed = updated.iter().find(|m| m.id == bob.id).unwrap();
    assert_eq!(bob_refreshed.role, TeamRole::Admin);

    // Cannot remove owner
    let err = team_remove_member(owner.id.clone()).unwrap_err();
    assert!(err.contains("owner"), "expected owner-protection, got: {err}");

    // Cannot demote last owner
    let err2 = team_update_role(owner.id.clone(), TeamRole::Member).unwrap_err();
    assert!(err2.contains("last owner"));

    // Remove bob
    team_remove_member(bob.id).unwrap();
    let after = team_get_members().unwrap();
    assert_eq!(after.len(), 1);
    assert_eq!(after[0].id, owner.id);
}

#[test]
fn team_sync_now_is_noop_without_repo_path() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    // No team_repo_path configured — should return 0 rather than error.
    let changed = team_sync_now().unwrap();
    assert_eq!(changed, 0);
}
