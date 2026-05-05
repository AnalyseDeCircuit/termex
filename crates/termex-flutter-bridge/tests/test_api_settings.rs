use termex_flutter_bridge::api::settings::*;

// ─── settings_load ────────────────────────────────────────────────────────────

#[test]
fn test_settings_load_returns_defaults() {
    let s = settings_load().expect("settings_load should succeed");
    // Verify a representative subset of default values.
    assert_eq!(s.theme_mode, "system");
    assert_eq!(s.font_size, 14.0);
    assert_eq!(s.tab_width, 4);
    assert!(s.scrollback_lines > 0);
    assert_eq!(s.language, "en-US");
}

// ─── settings_save ───────────────────────────────────────────────────────────

#[test]
fn test_settings_save_returns_ok() {
    let s = settings_load().unwrap();
    settings_save(s).expect("settings_save should succeed");
}

// ─── settings_export / import ────────────────────────────────────────────────

#[test]
fn test_settings_export_import_roundtrip() {
    // Stubs: both must succeed without panicking.
    settings_export("/tmp/termex_settings_test.enc".into(), "s3cr3t".into())
        .expect("export should succeed");
    let s = settings_import("/tmp/termex_settings_test.enc".into(), "s3cr3t".into())
        .expect("import should succeed");
    // Stub returns defaults regardless of path.
    assert_eq!(s.theme_mode, "system");
}

// ─── settings_reset ──────────────────────────────────────────────────────────

#[test]
fn test_settings_reset_returns_ok() {
    settings_reset_to_defaults().expect("reset should succeed");
}

// ─── privacy: clear functions ─────────────────────────────────────────────────

#[test]
fn test_privacy_clear_functions_all_ok() {
    privacy_clear_connection_history().expect("clear connection history should succeed");
    privacy_clear_ai_conversations().expect("clear AI conversations should succeed");
    privacy_clear_snippet_stats().expect("clear snippet stats should succeed");
}

// ─── GDPR erase ──────────────────────────────────────────────────────────────

#[test]
fn test_gdpr_erase_requires_correct_confirmation() {
    let err = privacy_gdpr_erase_all("mypassword".into(), "wrong text".into())
        .expect_err("wrong confirmation should return Err");
    assert_eq!(err, "Confirmation text mismatch");
}

#[test]
fn test_gdpr_erase_succeeds_with_correct_confirmation() {
    privacy_gdpr_erase_all("mypassword".into(), "DELETE ALL".into())
        .expect("correct confirmation should succeed");
}

// ─── audit_list ───────────────────────────────────────────────────────────────

#[test]
fn test_audit_list_returns_empty() {
    let entries = audit_list(100, None).expect("audit_list should succeed");
    assert!(entries.is_empty(), "stub should return empty list");
}

#[test]
fn test_audit_list_with_event_type_filter_returns_empty() {
    let entries =
        audit_list(50, Some("login".into())).expect("audit_list with filter should succeed");
    assert!(entries.is_empty());
}

// ─── audit_export_csv ─────────────────────────────────────────────────────────

#[test]
fn test_audit_export_csv_returns_ok() {
    audit_export_csv("/tmp/termex_audit_test.csv".into(), Some(30))
        .expect("audit_export_csv should succeed");
}
