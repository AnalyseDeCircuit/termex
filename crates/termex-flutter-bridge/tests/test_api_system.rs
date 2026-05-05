/// Tests for system.rs (clipboard + URL validation + window-state persistence).
use termex_flutter_bridge::api::system::*;

// ─── Clipboard ────────────────────────────────────────────────────────────────

#[test]
fn test_clipboard_write_and_read() {
    clipboard_write("hello clipboard".to_string()).unwrap();
    let text = clipboard_read().unwrap();
    assert_eq!(text, "hello clipboard");
}

#[test]
fn test_clipboard_clear() {
    clipboard_write("some text".to_string()).unwrap();
    clipboard_clear().unwrap();
    let text = clipboard_read().unwrap();
    assert_eq!(text, "");
}

#[test]
fn test_clipboard_overwrite() {
    clipboard_write("first".to_string()).unwrap();
    clipboard_write("second".to_string()).unwrap();
    assert_eq!(clipboard_read().unwrap(), "second");
}

// ─── URL validation ───────────────────────────────────────────────────────────

#[test]
fn test_url_can_open_https() {
    assert!(url_can_open("https://example.com".to_string()));
}

#[test]
fn test_url_can_open_http() {
    assert!(url_can_open("http://localhost:8080".to_string()));
}

#[test]
fn test_url_can_open_ssh() {
    assert!(url_can_open("ssh://user@host".to_string()));
}

#[test]
fn test_url_can_open_mailto() {
    assert!(url_can_open("mailto:user@example.com".to_string()));
}

#[test]
fn test_url_can_open_rejects_ftp() {
    assert!(!url_can_open("ftp://evil.com".to_string()));
}

#[test]
fn test_url_can_open_rejects_javascript() {
    assert!(!url_can_open("javascript:alert(1)".to_string()));
}

#[test]
fn test_url_validate_ok() {
    assert!(url_validate("https://anthropic.com".to_string()).is_ok());
}

#[test]
fn test_url_validate_err() {
    let err = url_validate("file:///etc/passwd".to_string());
    assert!(err.is_err());
    assert!(err.unwrap_err().contains("not allowed"));
}

// ─── Window state (no-DB path) ────────────────────────────────────────────────

#[test]
fn test_window_state_save_no_db_is_noop() {
    // Database is not unlocked in unit tests — save should succeed silently.
    let ws = WindowState {
        width: 1400.0,
        height: 900.0,
        x: 50.0,
        y: 50.0,
        is_maximized: false,
        open_tab_server_ids: vec!["srv-1".to_string()],
    };
    assert!(window_state_save(ws).is_ok());
}

#[test]
fn test_window_state_restore_returns_default_without_db() {
    let ws = window_state_restore().unwrap();
    // Defaults from WindowState::default_state().
    assert_eq!(ws.width, 1280.0);
    assert_eq!(ws.height, 800.0);
    assert!(!ws.is_maximized);
    assert!(ws.open_tab_server_ids.is_empty());
}

#[test]
fn test_window_state_reset_no_db_is_noop() {
    assert!(window_state_reset().is_ok());
}
