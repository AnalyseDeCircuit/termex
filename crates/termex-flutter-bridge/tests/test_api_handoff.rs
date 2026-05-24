//! Bridge-level tests for the v0.74.2 handoff registry API.

use std::sync::Mutex;
use tempfile::TempDir;

use termex_core::storage::db::Database;
use termex_flutter_bridge::api::handoff::*;
use termex_flutter_bridge::db_state;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    dir
}

fn dto(id: &str, name: &str, platform: &str, last_seen: &str) -> DeviceDto {
    DeviceDto {
        id: id.into(),
        name: name.into(),
        platform: platform.into(),
        first_seen_at: "2026-01-01T00:00:00Z".into(),
        last_seen_at: last_seen.into(),
        push_token: None,
        push_platform: None,
    }
}

#[test]
fn upsert_then_get_round_trip() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    let d = dto("d1", "iPhone", "ios", "2026-05-22T00:00:00Z");
    handoff_upsert_device(d.clone()).unwrap();
    let got = handoff_get_device("d1".into()).unwrap().unwrap();
    assert_eq!(got.id, "d1");
    assert_eq!(got.name, "iPhone");
    assert_eq!(got.platform, "ios");
}

#[test]
fn upsert_unknown_platform_errors() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    let bad = dto("d1", "?", "plan9", "2026-05-22T00:00:00Z");
    let err = handoff_upsert_device(bad).unwrap_err();
    assert!(err.contains("unknown platform"));
}

#[test]
fn touch_updates_last_seen() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    handoff_upsert_device(dto("d1", "iPhone", "ios", "2026-05-22T00:00:00Z")).unwrap();
    handoff_touch_device("d1".into(), "2026-05-23T12:00:00Z".into()).unwrap();
    let got = handoff_get_device("d1".into()).unwrap().unwrap();
    assert_eq!(got.last_seen_at, "2026-05-23T12:00:00Z");
}

#[test]
fn list_returns_in_recency_order() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    handoff_upsert_device(dto("a", "A", "ios", "2026-05-22T00:00:00Z")).unwrap();
    handoff_upsert_device(dto("b", "B", "macos", "2026-05-23T00:00:00Z")).unwrap();
    let l = handoff_list_devices().unwrap();
    assert_eq!(l[0].id, "b");
    assert_eq!(l[1].id, "a");
}

#[test]
fn delete_removes_then_get_returns_none() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    handoff_upsert_device(dto("d1", "iPhone", "ios", "2026-05-22T00:00:00Z")).unwrap();
    handoff_delete_device("d1".into()).unwrap();
    assert!(handoff_get_device("d1".into()).unwrap().is_none());
}

#[test]
fn prune_drops_stale_devices() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    handoff_upsert_device(dto("old", "Old", "linux", "2025-12-01T00:00:00Z")).unwrap();
    handoff_upsert_device(dto("fresh", "Fresh", "ios", "2026-05-22T00:00:00Z")).unwrap();
    let n = handoff_prune_stale("2026-02-01T00:00:00Z".into()).unwrap();
    assert_eq!(n, 1);
    assert!(handoff_get_device("old".into()).unwrap().is_none());
    assert!(handoff_get_device("fresh".into()).unwrap().is_some());
}

#[test]
fn push_platform_round_trips() {
    let _l = TEST_LOCK.lock().unwrap();
    let _d = setup();
    let mut d = dto("d1", "iPhone", "ios", "2026-05-22T00:00:00Z");
    d.push_token = Some("apns-token".into());
    d.push_platform = Some("ios_apns".into());
    handoff_upsert_device(d).unwrap();
    let got = handoff_get_device("d1".into()).unwrap().unwrap();
    assert_eq!(got.push_token.as_deref(), Some("apns-token"));
    assert_eq!(got.push_platform.as_deref(), Some("ios_apns"));
}
