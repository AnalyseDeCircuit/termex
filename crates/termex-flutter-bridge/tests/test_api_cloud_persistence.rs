//! v0.46 cloud persistence tests: ECS favourites + credential profiles.

use std::sync::Mutex;
use tempfile::TempDir;

use termex_core::storage::db::Database;
use termex_flutter_bridge::api::cloud::*;
use termex_flutter_bridge::db_state;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    dir
}

#[test]
fn test_ecs_add_and_list_favorite() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let f = cloud_ecs_add_favorite(
        "i-abc123".into(),
        "prod-app-01".into(),
        "cn-hangzhou".into(),
        "ecs.cn-hangzhou.aliyuncs.com".into(),
    )
    .unwrap();
    assert!(!f.id.is_empty());

    let list = cloud_ecs_list_favorites().unwrap();
    assert_eq!(list.len(), 1);
    assert_eq!(list[0].instance_id, "i-abc123");
    assert_eq!(list[0].name, "prod-app-01");
    assert_eq!(list[0].region, "cn-hangzhou");
}

#[test]
fn test_ecs_remove_favorite_deletes_row() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let f = cloud_ecs_add_favorite(
        "i-xyz".into(),
        "test".into(),
        "us-west-1".into(),
        "".into(),
    )
    .unwrap();

    cloud_ecs_remove_favorite(f.id).unwrap();
    assert!(cloud_ecs_list_favorites().unwrap().is_empty());
}

#[test]
fn test_cloud_save_and_load_credential() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    cloud_save_credential(CloudCredential {
        provider: "aws".into(),
        key_id: Some("prod".into()),
        region: Some("us-east-1".into()),
    })
    .unwrap();

    let loaded = cloud_load_credential("aws".into()).unwrap();
    assert!(loaded.is_some());
    let c = loaded.unwrap();
    assert_eq!(c.key_id.as_deref(), Some("prod"));
    assert_eq!(c.region.as_deref(), Some("us-east-1"));
}

#[test]
fn test_cloud_load_credential_missing_provider_returns_none() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let loaded = cloud_load_credential("does-not-exist".into()).unwrap();
    assert!(loaded.is_none());
}
