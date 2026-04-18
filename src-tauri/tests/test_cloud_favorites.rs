use termex_lib::storage::cloud_favorites::*;
use termex_lib::storage::migrations::run_migrations;

fn fresh_db() -> rusqlite::Connection {
    let conn = rusqlite::Connection::open_in_memory().unwrap();
    run_migrations(&conn).unwrap();
    conn
}

#[test]
fn test_cloud_favorite_crud() {
    let conn = fresh_db();

    // Create a kube favorite
    let input = CloudFavoriteInput {
        name: "prod-cluster".to_string(),
        resource_type: "kube".to_string(),
        context_or_profile: "arn:aws:eks:us-east-1:prod".to_string(),
        namespace: Some("default".to_string()),
        region: None,
    };
    let fav = create(&conn, &input).unwrap();
    assert_eq!(fav.name, "prod-cluster");
    assert_eq!(fav.resource_type, "kube");
    assert!(!fav.shared);
    assert!(fav.team_id.is_none());

    // List
    let all = list(&conn).unwrap();
    assert_eq!(all.len(), 1);

    // Get by ID
    let fetched = get(&conn, &fav.id).unwrap().unwrap();
    assert_eq!(fetched.context_or_profile, "arn:aws:eks:us-east-1:prod");

    // Find by ref
    let found = find_by_ref(&conn, "kube", "arn:aws:eks:us-east-1:prod").unwrap().unwrap();
    assert_eq!(found.id, fav.id);

    // Not found
    assert!(find_by_ref(&conn, "kube", "nonexistent").unwrap().is_none());

    // Set shared
    set_shared(&conn, &fav.id, true).unwrap();
    let shared = get(&conn, &fav.id).unwrap().unwrap();
    assert!(shared.shared);

    // Make local
    make_local(&conn, &fav.id).unwrap();
    let local = get(&conn, &fav.id).unwrap().unwrap();
    assert!(!local.shared);
    assert!(local.team_id.is_none());

    // Delete
    delete(&conn, &fav.id).unwrap();
    assert!(get(&conn, &fav.id).unwrap().is_none());
    assert_eq!(list(&conn).unwrap().len(), 0);
}

#[test]
fn test_cloud_favorite_ssm() {
    let conn = fresh_db();

    let input = CloudFavoriteInput {
        name: "aws-prod".to_string(),
        resource_type: "ssm".to_string(),
        context_or_profile: "production".to_string(),
        namespace: None,
        region: Some("us-east-1".to_string()),
    };
    let fav = create(&conn, &input).unwrap();
    assert_eq!(fav.resource_type, "ssm");
    assert_eq!(fav.region, Some("us-east-1".to_string()));

    let all = list(&conn).unwrap();
    assert_eq!(all.len(), 1);
    assert_eq!(all[0].name, "aws-prod");
}

#[test]
fn test_cloud_favorite_idempotent_find() {
    let conn = fresh_db();

    let input = CloudFavoriteInput {
        name: "staging".to_string(),
        resource_type: "kube".to_string(),
        context_or_profile: "staging-context".to_string(),
        namespace: None,
        region: None,
    };
    create(&conn, &input).unwrap();

    // Second create with same ref should be idempotent via find_by_ref
    let existing = find_by_ref(&conn, "kube", "staging-context").unwrap();
    assert!(existing.is_some());
    assert_eq!(list(&conn).unwrap().len(), 1);
}
