//! v0.47 proxy persistence + tor state tests (§8).

use std::sync::Mutex;
use tempfile::TempDir;

use termex_core::storage::db::Database;
use termex_flutter_bridge::api::proxy::*;
use termex_flutter_bridge::db_state;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    _test_clear_registry();
    dir
}

// ─── ProxyType enum ─────────────────────────────────────────────────────────

#[test]
fn test_proxy_type_roundtrip() {
    assert_eq!(ProxyType::from_str("socks5"), ProxyType::Socks5);
    assert_eq!(ProxyType::from_str("http"), ProxyType::Http);
    assert_eq!(ProxyType::from_str("tor"), ProxyType::Tor);
    assert_eq!(ProxyType::Socks5.as_str(), "socks5");
    assert_eq!(ProxyType::Http.as_str(), "http");
    assert_eq!(ProxyType::Tor.as_str(), "tor");
}

#[test]
fn test_proxy_keychain_key_format() {
    let key = proxy_keychain_key("abc-123");
    assert_eq!(key, "proxy:abc-123:password");
}

// ─── Persistence ────────────────────────────────────────────────────────────

#[test]
fn test_proxy_create_persists_to_db() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let p = proxy_create_ex(
        "Office SOCKS5".into(),
        ProxyType::Socks5,
        "10.0.0.1".into(),
        1080,
        Some("alice".into()),
        true,
    )
    .unwrap();

    assert!(!p.id.is_empty());
    assert_eq!(p.name, "Office SOCKS5");
    assert!(p.tls_enabled);

    // Clear in-memory registry → force DB fallback path.
    _test_clear_registry();
    let list = proxy_list().unwrap();
    assert_eq!(list.len(), 1);
    assert_eq!(list[0].host, "10.0.0.1");
    assert_eq!(list[0].port, 1080);
    assert!(list[0].tls_enabled);
}

#[test]
fn test_proxy_delete_removes_from_db() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let p = proxy_create_ex(
        "tmp".into(),
        ProxyType::Http,
        "host".into(),
        8080,
        None,
        false,
    )
    .unwrap();
    proxy_delete(p.id.clone()).unwrap();
    _test_clear_registry();
    assert!(proxy_list().unwrap().is_empty());
}

#[test]
fn test_proxy_set_default_rehydrates_from_db() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let p = proxy_create_ex(
        "tmp".into(),
        ProxyType::Socks5,
        "host".into(),
        1080,
        None,
        false,
    )
    .unwrap();
    // Clear registry; set_default should rehydrate from DB.
    _test_clear_registry();
    proxy_set_default(p.id.clone()).unwrap();
    let def = proxy_get_default().unwrap();
    assert!(def.is_some());
    assert_eq!(def.unwrap().id, p.id);
}

#[test]
fn test_proxy_record_health_updates_latency() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let p = proxy_create_ex(
        "x".into(),
        ProxyType::Socks5,
        "host".into(),
        1080,
        None,
        false,
    )
    .unwrap();
    proxy_record_health(p.id.clone(), Some(42));
    let list = proxy_list().unwrap();
    let matched = list.iter().find(|c| c.id == p.id).unwrap();
    assert_eq!(matched.health_ms, Some(42));
}

// ─── Tor ────────────────────────────────────────────────────────────────────

#[test]
fn test_tor_start_sets_running() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let port = tor_start().unwrap();
    assert_eq!(port, 9150);
    let st = tor_status();
    assert!(st.running);
    assert_eq!(st.bootstrap_percent, 100);
    assert_eq!(st.socks_port, Some(9150));
}

#[test]
fn test_tor_stop_clears_state() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let _ = tor_start().unwrap();
    tor_stop().unwrap();
    let st = tor_status();
    assert!(!st.running);
    assert_eq!(st.bootstrap_percent, 0);
    assert!(st.socks_port.is_none());
}

#[test]
fn test_tor_start_twice_is_idempotent() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let p1 = tor_start().unwrap();
    let p2 = tor_start().unwrap();
    assert_eq!(p1, p2);
}
