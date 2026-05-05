use std::sync::{Mutex, MutexGuard};

use termex_flutter_bridge::api::port_forward::*;

static PF_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> MutexGuard<'static, ()> {
    let guard = PF_LOCK.lock().unwrap();
    _test_clear_registry();
    guard
}

// ─── Start ────────────────────────────────────────────────────────────────────

#[test]
fn test_port_forward_start_returns_id() {
    let _guard = setup();
    let id = port_forward_start(
        "session-1".into(),
        ForwardType::Local,
        8080,
        "remote-host".into(),
        80,
    )
    .unwrap();
    assert!(!id.is_empty());
}

#[test]
fn test_port_forward_start_unique_ids() {
    let _guard = setup();
    let id1 = port_forward_start("session-u".into(), ForwardType::Local, 8080, "h".into(), 80).unwrap();
    let id2 = port_forward_start("session-u".into(), ForwardType::Local, 8081, "h".into(), 80).unwrap();
    assert_ne!(id1, id2);
}

#[test]
fn test_port_forward_start_rule_is_active() {
    let _guard = setup();
    let id = port_forward_start("session-a".into(), ForwardType::Remote, 9090, "host".into(), 9091).unwrap();
    let rules = port_forward_list_all().unwrap();
    let rule = rules.iter().find(|r| r.id == id).expect("rule should exist");
    assert!(rule.is_active);
}

// ─── Stop ─────────────────────────────────────────────────────────────────────

#[test]
fn test_port_forward_stop_removes_rule() {
    let _guard = setup();
    let id = port_forward_start("session-s".into(), ForwardType::Local, 7070, "h".into(), 70).unwrap();
    port_forward_stop(id.clone()).unwrap();
    let rules = port_forward_list_all().unwrap();
    assert!(rules.iter().all(|r| r.id != id), "rule should be removed after stop");
}

#[test]
fn test_port_forward_stop_nonexistent_is_ok() {
    let _guard = setup();
    port_forward_stop("nonexistent-id".into()).unwrap();
}

// ─── List by session ─────────────────────────────────────────────────────────

#[test]
fn test_port_forward_list_filters_by_session() {
    let _guard = setup();
    let sid_a = "sess-filter-a";
    let sid_b = "sess-filter-b";

    port_forward_start(sid_a.into(), ForwardType::Local, 1111, "h".into(), 22).unwrap();
    port_forward_start(sid_a.into(), ForwardType::Remote, 2222, "h".into(), 22).unwrap();
    port_forward_start(sid_b.into(), ForwardType::Dynamic, 3333, "h".into(), 22).unwrap();

    let rules_a = port_forward_list(sid_a.into()).unwrap();
    assert_eq!(rules_a.len(), 2, "session A should have 2 rules");

    let rules_b = port_forward_list(sid_b.into()).unwrap();
    assert_eq!(rules_b.len(), 1, "session B should have 1 rule");
}

// ─── List all ─────────────────────────────────────────────────────────────────

#[test]
fn test_port_forward_list_all_returns_all() {
    let _guard = setup();
    port_forward_start("sess-x".into(), ForwardType::Local, 4444, "h".into(), 22).unwrap();
    port_forward_start("sess-y".into(), ForwardType::Local, 5555, "h".into(), 22).unwrap();

    let all = port_forward_list_all().unwrap();
    assert_eq!(all.len(), 2);
}

#[test]
fn test_port_forward_list_all_empty_initially() {
    let _guard = setup();
    let all = port_forward_list_all().unwrap();
    assert!(all.is_empty());
}
