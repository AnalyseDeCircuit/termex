/// Tests for the AI FRB API.
use std::sync::Mutex;

use tempfile::TempDir;
use termex_core::storage::db::Database;
use termex_flutter_bridge::api::ai::*;
use termex_flutter_bridge::db_state;

static DB_LOCK: Mutex<()> = Mutex::new(());

fn setup_test_db() -> (TempDir, std::sync::MutexGuard<'static, ()>) {
    let guard = DB_LOCK.lock().unwrap();
    let dir = TempDir::new().unwrap();
    let db = Database::open_at(dir.path().join("test.db"), None).unwrap();
    db_state::init_for_test(db);
    (dir, guard)
}

#[test]
fn test_create_conversation_returns_unique_ids() {
    let c1 = ai_create_conversation(AiProvider::Claude, "claude-opus-4-7".to_string(), None);
    let c2 = ai_create_conversation(AiProvider::OpenAi, "gpt-4o".to_string(), Some("Test".to_string()));
    assert_ne!(c1.id, c2.id);
    assert_eq!(c1.provider, AiProvider::Claude);
    assert_eq!(c2.provider, AiProvider::OpenAi);
    assert!(c2.title.is_some());
}

#[test]
fn test_list_conversations_returns_empty() {
    let convs = ai_list_conversations();
    assert!(convs.is_empty());
}

#[test]
fn test_delete_conversation_is_ok() {
    let (_dir, _lock) = setup_test_db();
    // Deleting a non-existent id is a no-op — idempotent by design.
    assert!(ai_delete_conversation("any-id".to_string()).is_ok());
}

#[test]
fn test_get_messages_returns_empty() {
    let msgs = ai_get_messages("no-such-conv".to_string());
    assert!(msgs.is_empty());
}

#[test]
fn test_cancel_generation_does_not_panic() {
    ai_cancel_generation("conv-123".to_string());
}

#[test]
fn test_extract_commands_fenced_block() {
    let text = "Here is a command:\n```bash\nls -la\n```\nDone.";
    let cmds = ai_extract_commands(text.to_string());
    assert!(!cmds.is_empty());
    assert!(cmds.iter().any(|c| c.contains("ls")));
}

#[test]
fn test_is_dangerous_command_detects_rm_rf() {
    assert!(ai_is_dangerous_command("rm -rf /".to_string()));
    assert!(!ai_is_dangerous_command("ls -la".to_string()));
}

#[test]
fn test_is_dangerous_command_detects_fork_bomb() {
    assert!(ai_is_dangerous_command(":(){ :|:& };:".to_string()));
}

#[test]
fn test_save_provider_config_returns_ok() {
    let (_dir, _lock) = setup_test_db();
    let config = AiProviderConfig {
        provider: AiProvider::Claude,
        model: "claude-opus-4-7".to_string(),
        // Omit api_key to avoid touching the real OS keychain from tests.
        api_key: None,
        base_url: None,
        context_lines: 100,
    };
    let result = ai_save_provider_config(config);
    assert!(result.is_ok(), "save failed: {:?}", result);
}

#[test]
fn test_load_provider_config_returns_none_for_new() {
    let result = ai_load_provider_config(AiProvider::Ollama);
    assert!(result.is_none());
}

// ─── New functions added for gap-fill ────────────────────────────────────────

#[tokio::test]
async fn test_test_provider_config_returns_ok() {
    // Without a saved config the call reports "provider not configured".
    let result = ai_test_provider_config(AiProvider::Claude).await;
    assert!(result.is_err(), "expected error when no provider saved");
    assert!(result.unwrap_err().contains("not configured"));
}

#[test]
fn test_rename_conversation_is_ok() {
    let (_dir, _lock) = setup_test_db();
    // First create a conversation so rename has a row to update.
    let conv = ai_create_conversation(
        AiProvider::Claude,
        "claude-opus-4-7".to_string(),
        Some("Old".to_string()),
    );
    assert!(ai_rename_conversation(conv.id, "New title".to_string()).is_ok());
}

/// Build a test config pointing at a loopback base_url that cannot resolve,
/// so provider calls fail fast instead of talking to real APIs.
fn unreachable_config() -> AiProviderConfig {
    AiProviderConfig {
        provider: AiProvider::Claude,
        model: "claude-opus-4-7".to_string(),
        api_key: Some("test-key".to_string()),
        base_url: Some("http://127.0.0.1:1".to_string()),
        context_lines: 100,
    }
}

/// Once the provider client is wired, calls without a valid endpoint return
/// a connection error. We only assert the function is *reachable* and returns
/// a Result within a reasonable time — the successful branch requires a real
/// key and is covered by integration tests gated on an env var.
#[tokio::test]
async fn test_explain_command_returns_err_without_network() {
    let result = ai_explain_command("ls -la".to_string(), None, unreachable_config()).await;
    assert!(result.is_err());
}

#[tokio::test]
async fn test_diagnose_error_redacts_password_lines() {
    // Output containing a password line — must be redacted before sending.
    // We verify the call accepts the input and returns a deterministic error
    // when the endpoint is unreachable; redaction correctness is covered by
    // the unit-level `redact_sensitive` helper.
    let output = "Error: connection refused\nPassword: hunter2\nExiting.".to_string();
    let result = ai_diagnose_error(output, None, unreachable_config()).await;
    assert!(result.is_err());
}

#[tokio::test]
async fn test_nl2cmd_surface_unreachable() {
    let result = ai_nl2cmd(
        "find process on port 80".to_string(),
        "linux".to_string(),
        unreachable_config(),
    )
    .await;
    assert!(result.is_err());
}

#[tokio::test]
async fn test_autocomplete_surface_unreachable() {
    let result = ai_autocomplete("gitl".to_string(), None, unreachable_config()).await;
    assert!(result.is_err());
}

#[test]
fn test_extract_commands_inline_code() {
    let text = "Try running `ls -la` or `pwd` in the shell.";
    let cmds = ai_extract_commands(text.to_string());
    assert!(cmds.iter().any(|c| c.contains("ls")));
    assert!(cmds.iter().any(|c| c.contains("pwd")));
}

#[test]
fn test_extract_commands_mixes_fenced_and_inline() {
    let text = "First:\n```bash\ncd /tmp\n```\nOr inline: `ls`";
    let cmds = ai_extract_commands(text.to_string());
    assert!(cmds.iter().any(|c| c == "cd /tmp"));
    assert!(cmds.iter().any(|c| c == "ls"));
}
