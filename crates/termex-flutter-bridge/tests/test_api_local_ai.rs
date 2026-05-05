/// Tests for the Local AI FRB API stubs.
use termex_flutter_bridge::api::local_ai::*;

#[test]
fn test_list_models_returns_catalogue() {
    let models = local_ai_list_models();
    assert!(!models.is_empty(), "catalogue should not be empty");
    // All models start as not-downloaded
    assert!(models.iter().all(|m| !m.is_downloaded));
}

#[test]
fn test_list_models_have_valid_sizes() {
    for model in local_ai_list_models() {
        assert!(model.size_bytes > 0, "model {} has 0 bytes", model.id);
        assert!(!model.size_label.is_empty());
    }
}

#[test]
fn test_base_url_is_localhost() {
    let url = local_ai_base_url();
    assert!(url.contains("127.0.0.1") || url.contains("localhost"));
}

#[tokio::test]
async fn test_health_returns_stopped_when_not_started() {
    let health = local_ai_health().await;
    assert_eq!(health.status, LocalAiStatus::Stopped);
}

#[tokio::test]
async fn test_stop_when_not_running_is_ok() {
    assert!(local_ai_stop().await.is_ok());
}

#[tokio::test]
async fn test_delete_model_returns_ok() {
    let result: Result<(), String> = local_ai_delete_model("nonexistent".to_string()).await;
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_download_model_unknown_id_errors_fast() {
    // Fast path: unknown model ID returns Err synchronously without any HTTP.
    let result: Result<(), String> = local_ai_download_model("does-not-exist".to_string()).await;
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("unknown model"));
}

#[test]
fn test_cancel_download_does_not_panic() {
    local_ai_cancel_download("any-model".to_string());
}

// ─── New functions added for gap-fill ────────────────────────────────────────

#[test]
fn test_check_disk_space_returns_bytes() {
    let space = local_ai_check_disk_space().unwrap();
    // Stub returns 20 GB; just check it's a plausible value.
    assert!(space > 0, "disk space should be non-zero");
}

#[test]
fn test_cancel_auto_start_does_not_panic() {
    local_ai_cancel_auto_start();
}
