use termex_lib::ssh::forward::{new_registry, stop_forward, ActiveForward};
use tokio_util::sync::CancellationToken;

#[tokio::test]
async fn test_registry_create_and_remove() {
    let registry = new_registry();
    assert!(registry.read().await.is_empty());

    let cancel = CancellationToken::new();
    let task = tokio::spawn(async {});
    let active = ActiveForward {
        id: "test-1".into(),
        cancel,
        task,
    };
    registry.write().await.insert("test-1".into(), active);
    assert_eq!(registry.read().await.len(), 1);

    stop_forward("test-1", &registry).await.unwrap();
    assert!(registry.read().await.is_empty());
}
