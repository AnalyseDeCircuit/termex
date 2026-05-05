//! v0.46 settings persistence tests: verify the settings KV table path.
//!
//! Integration-level tests share the global `DB` static, so each test in this
//! file must hold `TEST_LOCK` while running (mirrors the pattern in
//! `test_api_group.rs`).

use std::sync::Mutex;
use tempfile::TempDir;

use termex_core::storage::db::Database;
use termex_flutter_bridge::api::settings::*;
use termex_flutter_bridge::db_state;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    dir
}

#[test]
fn test_settings_save_then_load_roundtrip() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let mut s = AppSettings::default();
    s.theme_mode = "dark".into();
    s.font_size = 16.0;
    s.scrollback_lines = 9000;
    s.tab_width = 8;
    s.ai_context_lines = 200;

    settings_save(s.clone()).expect("save should succeed");

    let loaded = settings_load().expect("load should succeed");
    assert_eq!(loaded.theme_mode, "dark");
    assert_eq!(loaded.font_size, 16.0);
    assert_eq!(loaded.scrollback_lines, 9000);
    assert_eq!(loaded.tab_width, 8);
    assert_eq!(loaded.ai_context_lines, 200);
}

#[test]
fn test_settings_reset_clears_overrides() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let mut s = AppSettings::default();
    s.font_size = 22.0;
    settings_save(s).unwrap();

    settings_reset_to_defaults().expect("reset should succeed");

    let loaded = settings_load().unwrap();
    assert_eq!(loaded.font_size, AppSettings::default().font_size);
}

#[test]
fn test_settings_export_import_json_roundtrip() {
    let _lock = TEST_LOCK.lock().unwrap();
    let dir = setup();

    let mut s = AppSettings::default();
    s.color_scheme = "Gruvbox".into();
    s.language = "zh-CN".into();
    settings_save(s.clone()).unwrap();

    let path = dir.path().join("backup.json").to_string_lossy().to_string();
    settings_export(path.clone(), "pw".into()).expect("export should succeed");

    // Wipe overrides and re-import.
    settings_reset_to_defaults().unwrap();
    let restored =
        settings_import(path, "pw".into()).expect("import should succeed");
    assert_eq!(restored.color_scheme, "Gruvbox");
    assert_eq!(restored.language, "zh-CN");

    let reloaded = settings_load().unwrap();
    assert_eq!(reloaded.color_scheme, "Gruvbox");
}

#[test]
fn test_audit_append_and_list() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    audit_append("ssh.connect", "server=web-01").unwrap();
    audit_append("ssh.disconnect", "server=web-01").unwrap();
    audit_append("ssh.connect", "server=db-02").unwrap();

    let all = audit_list(50, None).unwrap();
    assert_eq!(all.len(), 3);
    // Newest-first ordering.
    assert_eq!(all[0].event_type, "ssh.connect");
    assert_eq!(all[0].detail, "server=db-02");

    let filtered = audit_list(50, Some("ssh.connect".into())).unwrap();
    assert_eq!(filtered.len(), 2);
    assert!(filtered.iter().all(|e| e.event_type == "ssh.connect"));
}

#[test]
fn test_audit_export_csv_writes_header_and_rows() {
    let _lock = TEST_LOCK.lock().unwrap();
    let dir = setup();

    audit_append("test.event", "detail one").unwrap();
    audit_append("test.event", "detail, with comma").unwrap();

    let path = dir.path().join("audit.csv").to_string_lossy().to_string();
    audit_export_csv(path.clone(), None).expect("export should succeed");

    let contents = std::fs::read_to_string(&path).unwrap();
    assert!(contents.starts_with('\u{FEFF}'), "BOM expected");
    assert!(contents.contains("timestamp,event_type,detail"));
    assert!(contents.contains("test.event,detail one"));
    // Commas inside a field must be quoted.
    assert!(contents.contains("\"detail, with comma\""));
}

#[test]
fn test_privacy_clear_snippet_stats_resets_counts() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    // Seed a snippet with non-zero usage via core_snippet API.
    use termex_core::storage::models::SnippetInput;
    use termex_core::storage::snippet as core_snippet;

    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let s = core_snippet::create(
                conn,
                &SnippetInput {
                    title: "test".into(),
                    description: None,
                    command: "ls".into(),
                    tags: vec![],
                    folder_id: None,
                    is_favorite: false,
                },
            )
            .map_err(rusqlite::Error::InvalidParameterName)?;
            core_snippet::record_usage(conn, &s.id)
                .map_err(rusqlite::Error::InvalidParameterName)?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
    .unwrap();

    privacy_clear_snippet_stats().unwrap();

    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let count: i64 = conn
                .query_row(
                    "SELECT COALESCE(SUM(usage_count), 0) FROM snippets",
                    [],
                    |r| r.get(0),
                )
                .unwrap_or(0);
            assert_eq!(count, 0, "usage_count must reset to 0");
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
    .unwrap();
}

#[test]
fn test_gdpr_erase_clears_business_data() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    audit_append("app.start", "").unwrap();

    privacy_gdpr_erase_all("pw".into(), "DELETE ALL".into())
        .expect("correct confirmation succeeds");

    let logs = audit_list(50, None).unwrap();
    assert!(logs.is_empty(), "audit_log should be wiped");
}

#[test]
fn test_gdpr_erase_wrong_confirmation_is_rejected() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let err = privacy_gdpr_erase_all("pw".into(), "delete all".into())
        .expect_err("lowercase confirmation must fail");
    assert!(err.contains("Confirmation"));
}

#[test]
fn test_settings_default_kubeconfig_path() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();
    let s = settings_load().unwrap();
    assert_eq!(s.k8s_kubeconfig_path, "~/.kube/config");
}

#[test]
fn test_settings_kubeconfig_path_persists() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let mut s = settings_load().unwrap();
    s.k8s_kubeconfig_path = "/etc/kubernetes/admin.conf".into();
    settings_save(s).unwrap();

    let loaded = settings_load().unwrap();
    assert_eq!(loaded.k8s_kubeconfig_path, "/etc/kubernetes/admin.conf");
}

#[test]
fn test_settings_export_with_password_uses_encrypted_format() {
    let _lock = TEST_LOCK.lock().unwrap();
    let dir = setup();

    let mut s = settings_load().unwrap();
    s.theme_mode = "dark".into();
    settings_save(s).unwrap();

    let path = dir.path().join("backup.termex").to_string_lossy().to_string();
    settings_export(path.clone(), "strong-pw".into()).unwrap();

    // File should start with TRMX magic header.
    let bytes = std::fs::read(&path).unwrap();
    assert_eq!(&bytes[0..4], b"TRMX");

    // Round-trip import.
    settings_reset_to_defaults().unwrap();
    let restored = settings_import(path, "strong-pw".into()).unwrap();
    assert_eq!(restored.theme_mode, "dark");
}
