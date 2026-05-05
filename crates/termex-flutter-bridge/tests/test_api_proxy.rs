use std::sync::{Mutex, MutexGuard};

use termex_flutter_bridge::api::proxy::*;

static PROXY_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> MutexGuard<'static, ()> {
    let guard = PROXY_LOCK.lock().unwrap();
    _test_clear_registry();
    guard
}

// ─── Create ───────────────────────────────────────────────────────────────────

#[test]
fn test_proxy_create_returns_config() {
    let _guard = setup();
    let cfg = proxy_create(ProxyType::Socks5, "127.0.0.1".into(), 1080, None).unwrap();
    assert!(!cfg.id.is_empty());
    assert_eq!(cfg.port, 1080);
    assert!(!cfg.is_default);
    assert!(cfg.username.is_none());
}

#[test]
fn test_proxy_create_with_username() {
    let _guard = setup();
    let cfg = proxy_create(ProxyType::Http, "proxy.local".into(), 8888, Some("admin".into())).unwrap();
    assert_eq!(cfg.username, Some("admin".into()));
}

#[test]
fn test_proxy_create_unique_ids() {
    let _guard = setup();
    let id1 = proxy_create(ProxyType::Socks5, "h".into(), 1080, None).unwrap().id;
    let id2 = proxy_create(ProxyType::Http, "h".into(), 8080, None).unwrap().id;
    assert_ne!(id1, id2);
}

// ─── List ─────────────────────────────────────────────────────────────────────

#[test]
fn test_proxy_list_empty_initially() {
    let _guard = setup();
    let list = proxy_list().unwrap();
    assert!(list.is_empty());
}

#[test]
fn test_proxy_list_contains_created() {
    let _guard = setup();
    proxy_create(ProxyType::Tor, "tor.proxy".into(), 9050, None).unwrap();
    let list = proxy_list().unwrap();
    assert_eq!(list.len(), 1);
}

// ─── Delete ───────────────────────────────────────────────────────────────────

#[test]
fn test_proxy_delete_ok() {
    let _guard = setup();
    let cfg = proxy_create(ProxyType::Socks5, "h".into(), 1080, None).unwrap();
    proxy_delete(cfg.id.clone()).unwrap();
    let list = proxy_list().unwrap();
    assert!(list.iter().all(|c| c.id != cfg.id));
}

// ─── Default ─────────────────────────────────────────────────────────────────

#[test]
fn test_proxy_get_default_none_initially() {
    let _guard = setup();
    let default = proxy_get_default().unwrap();
    assert!(default.is_none());
}

#[test]
fn test_proxy_set_default_works() {
    let _guard = setup();
    let cfg = proxy_create(ProxyType::Socks5, "h".into(), 1080, None).unwrap();
    proxy_set_default(cfg.id.clone()).unwrap();
    let default = proxy_get_default().unwrap().expect("default should be set");
    assert_eq!(default.id, cfg.id);
    assert!(default.is_default);
}

#[test]
fn test_proxy_set_default_clears_previous() {
    let _guard = setup();
    let cfg1 = proxy_create(ProxyType::Http, "h1".into(), 8080, None).unwrap();
    let cfg2 = proxy_create(ProxyType::Socks5, "h2".into(), 1080, None).unwrap();
    proxy_set_default(cfg1.id.clone()).unwrap();
    proxy_set_default(cfg2.id.clone()).unwrap();
    let default = proxy_get_default().unwrap().expect("default should be set");
    assert_eq!(default.id, cfg2.id);
    // cfg1 should no longer be default.
    let list = proxy_list().unwrap();
    let prev = list.iter().find(|c| c.id == cfg1.id).unwrap();
    assert!(!prev.is_default);
}

// ─── Test Connection ─────────────────────────────────────────────────────────

#[test]
fn test_proxy_test_connection_returns_false() {
    let _guard = setup();
    let cfg = proxy_create(ProxyType::Socks5, "h".into(), 1080, None).unwrap();
    let result = proxy_test_connection(cfg.id).unwrap();
    assert!(!result, "stub always returns false");
}
