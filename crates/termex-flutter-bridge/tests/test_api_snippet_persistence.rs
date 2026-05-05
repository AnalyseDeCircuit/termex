//! v0.46 snippet persistence tests: end-to-end CRUD through the FRB API.

use std::sync::Mutex;
use tempfile::TempDir;

use termex_core::storage::db::Database;
use termex_flutter_bridge::api::snippet::*;
use termex_flutter_bridge::db_state;

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> TempDir {
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    dir
}

#[test]
fn test_snippet_create_persists_and_appears_in_list() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let s = snippet_create(
        "Deploy".into(),
        "kubectl apply -f {{manifest}}".into(),
        Some("k8s".into()),
        vec!["deploy".into()],
    )
    .unwrap();

    let all = snippet_list(None, None).unwrap();
    assert_eq!(all.len(), 1);
    assert_eq!(all[0].id, s.id);
    assert_eq!(all[0].name, "Deploy");
    assert_eq!(all[0].group.as_deref(), Some("k8s"));
}

#[test]
fn test_snippet_update_changes_content() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let s = snippet_create("ping".into(), "ping {{host}}".into(), None, vec![]).unwrap();

    let updated = snippet_update(
        s.id.clone(),
        "ping v6".into(),
        "ping6 {{host}}".into(),
        Some("net".into()),
        vec!["ipv6".into()],
    )
    .unwrap();

    assert_eq!(updated.name, "ping v6");
    assert_eq!(updated.content, "ping6 {{host}}");

    let all = snippet_list(None, None).unwrap();
    assert_eq!(all.len(), 1);
    assert_eq!(all[0].name, "ping v6");
    assert_eq!(all[0].content, "ping6 {{host}}");
    assert_eq!(all[0].group.as_deref(), Some("net"));
}

#[test]
fn test_snippet_delete_removes_from_list() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let s = snippet_create("x".into(), "echo 1".into(), None, vec![]).unwrap();
    assert_eq!(snippet_list(None, None).unwrap().len(), 1);

    snippet_delete(s.id).unwrap();
    assert!(snippet_list(None, None).unwrap().is_empty());
}

#[test]
fn test_snippet_group_filter_applies() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    snippet_create("g1".into(), "cmd1".into(), Some("a".into()), vec![]).unwrap();
    snippet_create("g2".into(), "cmd2".into(), Some("b".into()), vec![]).unwrap();
    snippet_create("g3".into(), "cmd3".into(), Some("a".into()), vec![]).unwrap();

    let a_only = snippet_list(None, Some("a".into())).unwrap();
    assert_eq!(a_only.len(), 2);
    assert!(a_only.iter().all(|s| s.group.as_deref() == Some("a")));
}

#[test]
fn test_snippet_list_groups_returns_distinct_values() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    snippet_create("s1".into(), "c".into(), Some("foo".into()), vec![]).unwrap();
    snippet_create("s2".into(), "c".into(), Some("bar".into()), vec![]).unwrap();
    snippet_create("s3".into(), "c".into(), Some("foo".into()), vec![]).unwrap();

    let groups = snippet_list_groups().unwrap();
    assert_eq!(groups.len(), 2);
    assert!(groups.contains(&"foo".into()));
    assert!(groups.contains(&"bar".into()));
}

#[test]
fn test_snippet_record_use_increments_count() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    let s = snippet_create("use".into(), "echo".into(), None, vec![]).unwrap();

    snippet_record_use(s.id.clone()).unwrap();
    snippet_record_use(s.id.clone()).unwrap();

    let all = snippet_list(None, None).unwrap();
    assert_eq!(all[0].use_count, 2);
    assert!(all[0].last_used_at.is_some());
}

#[test]
fn test_snippet_query_filter_by_content() {
    let _lock = TEST_LOCK.lock().unwrap();
    let _dir = setup();

    snippet_create("docker".into(), "docker ps".into(), None, vec![]).unwrap();
    snippet_create("ping".into(), "ping 8.8.8.8".into(), None, vec![]).unwrap();

    let matched = snippet_list(Some("docker".into()), None).unwrap();
    assert_eq!(matched.len(), 1);
    assert_eq!(matched[0].name, "docker");
}
