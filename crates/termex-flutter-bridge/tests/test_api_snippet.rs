use termex_flutter_bridge::api::snippet::*;

// ─── snippet_create / snippet_list ───────────────────────────────────────────

#[test]
fn test_snippet_create_has_id_and_timestamp() {
    let s = snippet_create(
        "Deploy".into(),
        "kubectl apply -f {{manifest}}".into(),
        Some("k8s".into()),
        vec!["deploy".into(), "k8s".into()],
    )
    .expect("snippet_create should succeed");

    assert!(!s.id.is_empty(), "id must not be empty");
    assert!(!s.created_at.is_empty(), "created_at must not be empty");
    assert_eq!(s.name, "Deploy");
    assert_eq!(s.use_count, 0);
    assert!(s.last_used_at.is_none());
}

#[test]
fn test_snippet_create_and_list() {
    // List is a stub returning empty; create returns the new snippet.
    snippet_create("ping".into(), "ping {{host}}".into(), None, vec![])
        .expect("create should succeed");
    let list = snippet_list(None, None).expect("snippet_list should succeed");
    // Stub list returns empty — verify the call chain compiles and runs.
    let _ = list;
}

// ─── snippet_delete ───────────────────────────────────────────────────────────

#[test]
fn test_snippet_delete_ok() {
    snippet_delete("any-id".into()).expect("snippet_delete should succeed");
}

// ─── snippet_list_groups ──────────────────────────────────────────────────────

#[test]
fn test_snippet_list_groups_empty() {
    let groups = snippet_list_groups().expect("snippet_list_groups should succeed");
    assert!(groups.is_empty(), "stub should return empty list");
}

// ─── snippet_record_use ───────────────────────────────────────────────────────

#[test]
fn test_snippet_record_use_ok() {
    snippet_record_use("some-id".into()).expect("snippet_record_use should succeed");
}

// ─── snippet_extract_variables ───────────────────────────────────────────────

#[test]
fn test_snippet_extract_variables_simple() {
    let vars =
        snippet_extract_variables("ssh {{user}}@{{host}} -p {{port}}".into());
    assert_eq!(vars.len(), 3);
    assert_eq!(vars[0].name, "user");
    assert_eq!(vars[1].name, "host");
    assert_eq!(vars[2].name, "port");
    assert!(vars.iter().all(|v| v.default_value.is_none()));
}

#[test]
fn test_snippet_extract_variables_with_default() {
    let vars = snippet_extract_variables("ssh {{user:root}}@{{host}} -p {{port:22}}".into());
    assert_eq!(vars.len(), 3);
    assert_eq!(vars[0].name, "user");
    assert_eq!(vars[0].default_value, Some("root".into()));
    assert_eq!(vars[1].name, "host");
    assert_eq!(vars[1].default_value, None);
    assert_eq!(vars[2].name, "port");
    assert_eq!(vars[2].default_value, Some("22".into()));
}

#[test]
fn test_snippet_extract_variables_deduplicates() {
    let vars = snippet_extract_variables("{{x}} and {{x}} and {{y}}".into());
    assert_eq!(vars.len(), 2);
    assert_eq!(vars[0].name, "x");
    assert_eq!(vars[1].name, "y");
}

#[test]
fn test_snippet_extract_variables_empty_content() {
    let vars = snippet_extract_variables("no placeholders here".into());
    assert!(vars.is_empty());
}

// ─── snippet_resolve ─────────────────────────────────────────────────────────

#[test]
fn test_snippet_resolve_replaces_variables() {
    let result = snippet_resolve(
        "ssh {{user}}@{{host}} -p {{port}}".into(),
        vec![
            ("user".into(), "alice".into()),
            ("host".into(), "example.com".into()),
            ("port".into(), "2222".into()),
        ],
    );
    assert_eq!(result, "ssh alice@example.com -p 2222");
}

#[test]
fn test_snippet_resolve_missing_var_left_empty() {
    // Variables not provided are replaced with empty string.
    let result = snippet_resolve(
        "ping {{host}} count={{count}}".into(),
        vec![("host".into(), "10.0.0.1".into())],
    );
    // {{count}} has no value; after resolve it should be gone (empty).
    assert_eq!(result, "ping 10.0.0.1 count=");
}

#[test]
fn test_snippet_resolve_no_vars_unchanged() {
    let content = "ls -la /tmp".to_string();
    let result = snippet_resolve(content.clone(), vec![]);
    assert_eq!(result, content);
}
