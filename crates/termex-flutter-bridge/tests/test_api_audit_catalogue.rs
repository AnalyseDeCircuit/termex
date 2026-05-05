//! Tests for the v0.46 audit-event catalogue (§4.9.5).

use termex_flutter_bridge::api::audit_catalogue::*;

#[test]
fn test_audit_list_prefixes_has_eleven_entries() {
    let prefixes = audit_list_prefixes();
    assert_eq!(prefixes.len(), 11, "spec §4.9.5 defines 11 event prefixes");
    for expected in &[
        "app", "server", "ssh", "sftp", "ai", "local_ai",
        "team", "cloud", "snippet", "config", "keybinding",
    ] {
        assert!(prefixes.contains(&expected.to_string()),
                "missing prefix '{}'", expected);
    }
}

#[test]
fn test_audit_known_events_covers_every_prefix() {
    let events = audit_list_known_events();
    let prefixes = audit_list_prefixes();
    for prefix in &prefixes {
        assert!(
            events.iter().any(|e| e.starts_with(&format!("{prefix}."))),
            "prefix '{prefix}' has no events in the catalogue"
        );
    }
}

#[test]
fn test_audit_is_known_event_for_canonical_events() {
    assert!(audit_is_known_event("ssh.connect".into()));
    assert!(audit_is_known_event("team.invite_create".into()));
    assert!(audit_is_known_event("config.erase_all".into()));
    assert!(!audit_is_known_event("bogus.event".into()));
    assert!(!audit_is_known_event("".into()));
}

#[test]
fn test_audit_redact_detail_masks_password_value() {
    let out = audit_redact_detail("user=alice password:hunter2 port=22".into());
    assert!(out.contains("password:***"));
    assert!(!out.contains("hunter2"));
    assert!(out.contains("user=alice"));
    assert!(out.contains("port=22"));
}

#[test]
fn test_audit_redact_detail_masks_multiple_markers() {
    let out = audit_redact_detail(
        "token:abc123 passphrase:xyz api_key:secret-key".into(),
    );
    assert!(!out.contains("abc123"));
    assert!(!out.contains("xyz"));
    assert!(!out.contains("secret-key"));
    assert!(out.matches("***").count() == 3);
}

#[test]
fn test_audit_redact_detail_preserves_plain_text() {
    let input = "no sensitive markers here".to_string();
    assert_eq!(audit_redact_detail(input.clone()), input);
}
