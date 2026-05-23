//! Integration tests for the cross-device handoff core — device
//! registry CRUD/heartbeat/prune + ownership lock race semantics.

use rusqlite::Connection;

use termex_core::handoff::ownership::{
    current_owner, ensure_test_schema, release, try_takeover,
};
use termex_core::handoff::registry::{
    delete, ensure_schema, get, list, prune_older_than, touch_last_seen, upsert,
};
use termex_core::handoff::{
    Device, DevicePlatform, DeviceSummary, HandoffError, PushPlatform, TakeoverOutcome,
};

// ── registry helpers ────────────────────────────────────────────────

fn reg_db() -> Connection {
    let c = Connection::open_in_memory().unwrap();
    ensure_schema(&c).unwrap();
    c
}

fn device(id: &str, name: &str, platform: DevicePlatform, last_seen: &str) -> Device {
    Device {
        id: id.into(),
        name: name.into(),
        platform,
        first_seen_at: "2026-01-01T00:00:00Z".into(),
        last_seen_at: last_seen.into(),
        push_token: None,
        push_platform: None,
    }
}

// ── DevicePlatform / DeviceSummary ─────────────────────────────────

#[test]
fn platform_parse_round_trip() {
    for p in [
        DevicePlatform::Ios,
        DevicePlatform::Android,
        DevicePlatform::Macos,
        DevicePlatform::Linux,
        DevicePlatform::Windows,
    ] {
        assert_eq!(DevicePlatform::parse(p.as_str()), Some(p));
    }
    assert_eq!(DevicePlatform::parse("plan9"), None);
}

#[test]
fn platform_is_mobile_only_for_phones() {
    assert!(DevicePlatform::Ios.is_mobile());
    assert!(DevicePlatform::Android.is_mobile());
    assert!(!DevicePlatform::Macos.is_mobile());
    assert!(!DevicePlatform::Linux.is_mobile());
    assert!(!DevicePlatform::Windows.is_mobile());
}

#[test]
fn device_summary_strips_push_token() {
    let mut d = device("d1", "iPhone", DevicePlatform::Ios, "2026-05-22T00:00:00Z");
    d.push_token = Some("secret-token-xyz".into());
    d.push_platform = Some(PushPlatform::IosApns);
    let s = DeviceSummary::from(&d);
    assert_eq!(s.id, "d1");
    assert_eq!(s.name, "iPhone");
    assert_eq!(s.platform, DevicePlatform::Ios);
    // Round-trip the summary through serde to confirm no token field
    // leaks into the wire payload.
    let json = serde_json::to_string(&s).unwrap();
    assert!(!json.contains("secret-token-xyz"));
    assert!(!json.contains("push_token"));
}

// ── registry CRUD ──────────────────────────────────────────────────

#[test]
fn upsert_inserts_then_returns_via_get() {
    let c = reg_db();
    let d = device("d1", "iPhone 14", DevicePlatform::Ios, "2026-05-22T00:00:00Z");
    upsert(&c, &d).unwrap();
    let got = get(&c, "d1").unwrap().unwrap();
    assert_eq!(got, d);
}

#[test]
fn get_unknown_returns_none() {
    let c = reg_db();
    assert!(get(&c, "nope").unwrap().is_none());
}

#[test]
fn upsert_updates_name_and_last_seen_but_preserves_first_seen() {
    let c = reg_db();
    let mut d = device("d1", "iPhone 14", DevicePlatform::Ios, "2026-05-22T00:00:00Z");
    d.first_seen_at = "2026-01-01T00:00:00Z".into();
    upsert(&c, &d).unwrap();

    // Simulate user renaming + reconnecting later — the new payload
    // declares a later first_seen_at but the row should keep the
    // original (we never want "registered since" to slide forward).
    let mut renamed = d.clone();
    renamed.name = "Karpenwon's iPhone".into();
    renamed.last_seen_at = "2026-05-23T08:00:00Z".into();
    renamed.first_seen_at = "2026-05-23T08:00:00Z".into();
    upsert(&c, &renamed).unwrap();

    let got = get(&c, "d1").unwrap().unwrap();
    assert_eq!(got.name, "Karpenwon's iPhone");
    assert_eq!(got.last_seen_at, "2026-05-23T08:00:00Z");
    assert_eq!(got.first_seen_at, "2026-01-01T00:00:00Z");
}

#[test]
fn upsert_round_trips_push_token_and_platform() {
    let c = reg_db();
    let mut d = device("d1", "iPhone", DevicePlatform::Ios, "2026-05-22T00:00:00Z");
    d.push_token = Some("apns-token-abc".into());
    d.push_platform = Some(PushPlatform::IosApns);
    upsert(&c, &d).unwrap();
    let got = get(&c, "d1").unwrap().unwrap();
    assert_eq!(got.push_token.as_deref(), Some("apns-token-abc"));
    assert_eq!(got.push_platform, Some(PushPlatform::IosApns));
}

#[test]
fn upsert_clears_push_token_when_passed_none() {
    let c = reg_db();
    let mut d = device("d1", "iPhone", DevicePlatform::Ios, "2026-05-22T00:00:00Z");
    d.push_token = Some("old".into());
    d.push_platform = Some(PushPlatform::IosApns);
    upsert(&c, &d).unwrap();

    // User revokes push permission → client re-registers with None.
    d.push_token = None;
    d.push_platform = None;
    upsert(&c, &d).unwrap();

    let got = get(&c, "d1").unwrap().unwrap();
    assert!(got.push_token.is_none());
    assert!(got.push_platform.is_none());
}

#[test]
fn list_sorted_by_last_seen_desc() {
    let c = reg_db();
    upsert(&c, &device("a", "A", DevicePlatform::Ios, "2026-05-22T00:00:00Z")).unwrap();
    upsert(&c, &device("b", "B", DevicePlatform::Macos, "2026-05-23T00:00:00Z")).unwrap();
    upsert(&c, &device("c", "C", DevicePlatform::Linux, "2026-05-21T00:00:00Z")).unwrap();
    let l = list(&c).unwrap();
    assert_eq!(l.iter().map(|d| d.id.as_str()).collect::<Vec<_>>(),
               vec!["b", "a", "c"]);
}

#[test]
fn touch_last_seen_updates_only_heartbeat() {
    let c = reg_db();
    let d = device("d1", "iPhone", DevicePlatform::Ios, "2026-05-22T00:00:00Z");
    upsert(&c, &d).unwrap();
    touch_last_seen(&c, "d1", "2026-05-23T12:00:00Z").unwrap();
    let got = get(&c, "d1").unwrap().unwrap();
    assert_eq!(got.last_seen_at, "2026-05-23T12:00:00Z");
    assert_eq!(got.name, "iPhone");
}

#[test]
fn touch_last_seen_unknown_returns_unknown_device() {
    let c = reg_db();
    let err = touch_last_seen(&c, "nope", "2026-05-23T12:00:00Z").unwrap_err();
    assert!(matches!(err, HandoffError::UnknownDevice(_)));
}

#[test]
fn delete_removes_device() {
    let c = reg_db();
    let d = device("d1", "iPhone", DevicePlatform::Ios, "2026-05-22T00:00:00Z");
    upsert(&c, &d).unwrap();
    delete(&c, "d1").unwrap();
    assert!(get(&c, "d1").unwrap().is_none());
}

#[test]
fn delete_unknown_returns_unknown_device() {
    let c = reg_db();
    let err = delete(&c, "nope").unwrap_err();
    assert!(matches!(err, HandoffError::UnknownDevice(_)));
}

#[test]
fn prune_older_than_drops_stale_devices() {
    let c = reg_db();
    upsert(&c, &device("old", "Old", DevicePlatform::Linux, "2025-12-31T00:00:00Z")).unwrap();
    upsert(&c, &device("fresh", "Fresh", DevicePlatform::Ios, "2026-05-22T00:00:00Z")).unwrap();
    let n = prune_older_than(&c, "2026-02-01T00:00:00Z").unwrap();
    assert_eq!(n, 1);
    assert!(get(&c, "old").unwrap().is_none());
    assert!(get(&c, "fresh").unwrap().is_some());
}

// ── ownership lock ─────────────────────────────────────────────────

fn own_db() -> Connection {
    let c = Connection::open_in_memory().unwrap();
    ensure_test_schema(&c).unwrap();
    c.execute(
        "INSERT INTO tasks (id, primary_device_id, ownership_changed_at)
         VALUES ('t1', NULL, NULL)",
        [],
    )
    .unwrap();
    c
}

#[test]
fn current_owner_unowned_task_returns_none() {
    let c = own_db();
    assert_eq!(current_owner(&c, "t1").unwrap(), None);
}

#[test]
fn takeover_unowned_task_wins() {
    let mut c = own_db();
    let r = try_takeover(&mut c, "t1", "dev-A", None, "2026-05-23T00:00:00Z").unwrap();
    assert_eq!(r, TakeoverOutcome::Won { previous_owner_id: None });
    assert_eq!(current_owner(&c, "t1").unwrap().as_deref(), Some("dev-A"));
}

#[test]
fn takeover_idempotent_same_owner_no_race() {
    let mut c = own_db();
    try_takeover(&mut c, "t1", "dev-A", None, "2026-05-23T00:00:00Z").unwrap();
    let r = try_takeover(&mut c, "t1", "dev-A", None, "2026-05-23T00:01:00Z").unwrap();
    // No expectation passed + owner = new_owner → re-claim returns Won.
    match r {
        TakeoverOutcome::Won { previous_owner_id } => {
            assert_eq!(previous_owner_id.as_deref(), Some("dev-A"));
        }
        TakeoverOutcome::RaceLost { .. } => panic!("re-claim should be idempotent"),
    }
}

#[test]
fn takeover_without_expected_loses_to_existing_other_owner() {
    let mut c = own_db();
    try_takeover(&mut c, "t1", "dev-A", None, "2026-05-23T00:00:00Z").unwrap();
    // dev-B did not pass `expected = Some("dev-A")` — defensive
    // claim, so racer must learn the actual owner instead of
    // silently stealing.
    let r = try_takeover(&mut c, "t1", "dev-B", None, "2026-05-23T00:01:00Z").unwrap();
    match r {
        TakeoverOutcome::RaceLost { actual_owner_id } => {
            assert_eq!(actual_owner_id.as_deref(), Some("dev-A"));
        }
        TakeoverOutcome::Won { .. } => panic!("should have lost to existing owner"),
    }
    assert_eq!(current_owner(&c, "t1").unwrap().as_deref(), Some("dev-A"));
}

#[test]
fn takeover_with_matching_expected_swaps_owner() {
    let mut c = own_db();
    try_takeover(&mut c, "t1", "dev-A", None, "2026-05-23T00:00:00Z").unwrap();
    let r = try_takeover(
        &mut c,
        "t1",
        "dev-B",
        Some("dev-A"),
        "2026-05-23T00:01:00Z",
    )
    .unwrap();
    assert_eq!(
        r,
        TakeoverOutcome::Won {
            previous_owner_id: Some("dev-A".into())
        }
    );
    assert_eq!(current_owner(&c, "t1").unwrap().as_deref(), Some("dev-B"));
}

#[test]
fn takeover_with_stale_expected_loses_race() {
    let mut c = own_db();
    // A → B has already happened; C tries to take from A.
    try_takeover(&mut c, "t1", "dev-A", None, "2026-05-23T00:00:00Z").unwrap();
    try_takeover(
        &mut c,
        "t1",
        "dev-B",
        Some("dev-A"),
        "2026-05-23T00:01:00Z",
    )
    .unwrap();
    let r = try_takeover(
        &mut c,
        "t1",
        "dev-C",
        Some("dev-A"),
        "2026-05-23T00:02:00Z",
    )
    .unwrap();
    match r {
        TakeoverOutcome::RaceLost { actual_owner_id } => {
            assert_eq!(actual_owner_id.as_deref(), Some("dev-B"));
        }
        TakeoverOutcome::Won { .. } => panic!("stale expectation should lose"),
    }
    assert_eq!(current_owner(&c, "t1").unwrap().as_deref(), Some("dev-B"));
}

#[test]
fn takeover_expected_none_loses_when_actually_unowned() {
    // expected = Some("dev-A") but row is currently unowned → still
    // race-lost, since the caller's snapshot is stale.
    let mut c = own_db();
    let r = try_takeover(
        &mut c,
        "t1",
        "dev-B",
        Some("dev-A"),
        "2026-05-23T00:00:00Z",
    )
    .unwrap();
    match r {
        TakeoverOutcome::RaceLost { actual_owner_id } => {
            assert!(actual_owner_id.is_none());
        }
        TakeoverOutcome::Won { .. } => panic!("expected=Some must match exactly"),
    }
}

#[test]
fn release_clears_owner() {
    let mut c = own_db();
    try_takeover(&mut c, "t1", "dev-A", None, "2026-05-23T00:00:00Z").unwrap();
    release(&c, "t1", "2026-05-23T00:05:00Z").unwrap();
    assert_eq!(current_owner(&c, "t1").unwrap(), None);
}

#[test]
fn release_then_new_takeover_wins_clean() {
    let mut c = own_db();
    try_takeover(&mut c, "t1", "dev-A", None, "2026-05-23T00:00:00Z").unwrap();
    release(&c, "t1", "2026-05-23T00:05:00Z").unwrap();
    let r = try_takeover(&mut c, "t1", "dev-B", None, "2026-05-23T00:06:00Z").unwrap();
    assert_eq!(r, TakeoverOutcome::Won { previous_owner_id: None });
}
