use termex_flutter_bridge::api::cloud::*;

// ─── Kubernetes ───────────────────────────────────────────────────────────────

#[test]
fn test_cloud_k8s_list_contexts_empty() {
    let contexts = cloud_k8s_list_contexts().expect("cloud_k8s_list_contexts should succeed");
    assert!(contexts.is_empty(), "stub should return empty list");
}

#[test]
fn test_cloud_k8s_switch_context_ok() {
    cloud_k8s_switch_context("my-context".into())
        .expect("cloud_k8s_switch_context should succeed");
}

#[test]
fn test_cloud_k8s_list_pods_empty() {
    let pods = cloud_k8s_list_pods("ctx".into(), "default".into())
        .expect("cloud_k8s_list_pods should succeed");
    assert!(pods.is_empty(), "stub should return empty list");
}

#[test]
fn test_cloud_k8s_exec_returns_string() {
    let output = cloud_k8s_exec(
        "ctx".into(),
        "my-pod".into(),
        Some("my-container".into()),
        "ls /".into(),
    )
    .expect("cloud_k8s_exec should succeed");
    // Stub returns empty string.
    let _ = output;
}

// ─── AWS SSM ──────────────────────────────────────────────────────────────────

#[test]
fn test_cloud_ssm_list_empty() {
    let instances =
        cloud_ssm_list_instances("us-east-1".into()).expect("cloud_ssm_list_instances should succeed");
    assert!(instances.is_empty(), "stub should return empty list");
}

#[test]
fn test_cloud_ssm_start_session_returns_id() {
    let session_id = cloud_ssm_start_session("i-0123456789abcdef0".into(), "us-east-1".into())
        .expect("cloud_ssm_start_session should succeed");
    assert!(!session_id.is_empty(), "session_id must not be empty");
}

// ─── Alibaba Cloud ECS favourites ────────────────────────────────────────────

#[test]
fn test_cloud_ecs_add_and_remove_favorite() {
    let fav = cloud_ecs_add_favorite(
        "i-uf6j2g9vxxxxxx".into(),
        "prod-web".into(),
        "cn-hangzhou".into(),
        "47.1.2.3".into(),
    )
    .expect("cloud_ecs_add_favorite should succeed");

    assert!(!fav.id.is_empty(), "favorite id must not be empty");
    assert_eq!(fav.name, "prod-web");
    assert_eq!(fav.region, "cn-hangzhou");

    cloud_ecs_remove_favorite(fav.id).expect("cloud_ecs_remove_favorite should succeed");
}

#[test]
fn test_cloud_ecs_list_favorites_empty() {
    let favs = cloud_ecs_list_favorites().expect("cloud_ecs_list_favorites should succeed");
    assert!(favs.is_empty(), "stub should return empty list");
}

// ─── Credentials ─────────────────────────────────────────────────────────────

#[test]
fn test_cloud_load_credential_returns_none() {
    let cred = cloud_load_credential("aws".into()).expect("cloud_load_credential should succeed");
    assert!(cred.is_none(), "stub should return None");
}

#[test]
fn test_cloud_save_credential_ok() {
    cloud_save_credential(CloudCredential {
        provider: "aws".into(),
        key_id: Some("AKIAIOSFODNN7EXAMPLE".into()),
        region: Some("us-west-2".into()),
    })
    .expect("cloud_save_credential should succeed");
}
