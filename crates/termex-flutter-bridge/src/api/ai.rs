/// AI provider abstraction exposed to Flutter via FRB.
///
/// Supports multiple backends: Claude, OpenAI, Ollama, and local llama-server.
/// Streaming responses are delivered via a per-conversation event queue that
/// Dart polls through [`poll_ai_chunks`] — mirroring the SSH emitter model.
use flutter_rust_bridge::frb;
use uuid::Uuid;

use crate::db_state;
use termex_core::ai::provider_client::{self, ProviderKind, ProviderRequest};

// ─── DTOs ────────────────────────────────────────────────────────────────────

/// Supported AI providers.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiProvider {
    Claude,
    OpenAi,
    Ollama,
    LocalLlama,
}

/// Role of a message in a conversation.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MessageRole {
    User,
    Assistant,
    System,
}

/// A single conversation message sent to / received from the AI.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AiMessageDto {
    pub id: String,
    pub conversation_id: String,
    pub role: MessageRole,
    pub content: String,
    pub tokens_in: Option<i64>,
    pub tokens_out: Option<i64>,
    pub created_at: String,
}

/// A streaming chunk returned during AI generation.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AiChunkDto {
    pub conversation_id: String,
    pub message_id: String,
    /// Incremental text delta.
    pub delta: String,
    /// Set to true on the final chunk.
    pub done: bool,
    pub tokens_in: Option<i64>,
    pub tokens_out: Option<i64>,
    pub error: Option<String>,
}

/// A stored conversation header (no messages).
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConversationDto {
    pub id: String,
    pub provider: AiProvider,
    pub model: String,
    pub title: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

/// Configuration for a specific AI provider.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AiProviderConfig {
    pub provider: AiProvider,
    pub model: String,
    /// API key (stored in OS keychain; None = use keychain default).
    pub api_key: Option<String>,
    /// Custom base URL for Ollama or local llama-server.
    pub base_url: Option<String>,
    /// Max tokens to send as context from terminal scrollback.
    pub context_lines: i32,
}

/// Token usage returned for each completed message.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TokenUsage {
    pub tokens_in: i64,
    pub tokens_out: i64,
}

// ─── Conversation management ──────────────────────────────────────────────────

fn to_kind(p: &AiProvider) -> ProviderKind {
    match p {
        AiProvider::Claude => ProviderKind::Claude,
        AiProvider::OpenAi => ProviderKind::OpenAi,
        AiProvider::Ollama => ProviderKind::Ollama,
        AiProvider::LocalLlama => ProviderKind::LocalLlama,
    }
}

fn provider_to_str(p: &AiProvider) -> &'static str {
    match p {
        AiProvider::Claude => "claude",
        AiProvider::OpenAi => "openai",
        AiProvider::Ollama => "ollama",
        AiProvider::LocalLlama => "local_llama",
    }
}

fn provider_from_str(s: &str) -> AiProvider {
    match s {
        "claude" => AiProvider::Claude,
        "openai" => AiProvider::OpenAi,
        "ollama" => AiProvider::Ollama,
        "local_llama" => AiProvider::LocalLlama,
        _ => AiProvider::Claude,
    }
}

fn role_to_str(r: &MessageRole) -> &'static str {
    match r {
        MessageRole::User => "user",
        MessageRole::Assistant => "assistant",
        MessageRole::System => "system",
    }
}

fn role_from_str(s: &str) -> MessageRole {
    match s {
        "user" => MessageRole::User,
        "assistant" => MessageRole::Assistant,
        "system" => MessageRole::System,
        _ => MessageRole::User,
    }
}

/// Create a new conversation, persist its header, and return the DTO.
#[frb]
pub fn ai_create_conversation(
    provider: AiProvider,
    model: String,
    title: Option<String>,
) -> ConversationDto {
    let now = chrono::Utc::now().to_rfc3339();
    let dto = ConversationDto {
        id: Uuid::new_v4().to_string(),
        provider: provider.clone(),
        model: model.clone(),
        title: title.clone(),
        created_at: now.clone(),
        updated_at: now.clone(),
    };

    // Best-effort persist — an unopened database (test scope) shouldn't
    // crash the caller, it just means the conversation lives in memory
    // until the next unlock.
    let _ = db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "INSERT INTO ai_conversations (id, provider, model, title, created_at, updated_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
                rusqlite::params![
                    dto.id,
                    provider_to_str(&provider),
                    model,
                    title,
                    now,
                    now,
                ],
            )?;
            Ok::<(), rusqlite::Error>(())
        })
        .map_err(|e| e.to_string())
    });

    dto
}

/// List all stored conversations, most recent first.
/// Returns an empty list when the database is unavailable.
#[frb]
pub fn ai_list_conversations() -> Vec<ConversationDto> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, provider, model, title, created_at, updated_at
                 FROM ai_conversations
                 ORDER BY updated_at DESC",
            )?;
            let rows = stmt.query_map([], |row| {
                let provider: String = row.get(1)?;
                Ok(ConversationDto {
                    id: row.get(0)?,
                    provider: provider_from_str(&provider),
                    model: row.get(2)?,
                    title: row.get(3)?,
                    created_at: row.get(4)?,
                    updated_at: row.get(5)?,
                })
            })?;
            rows.collect::<rusqlite::Result<Vec<_>>>()
        })
        .map_err(|e| e.to_string())
    })
    .unwrap_or_default()
}

/// Delete a conversation and all its messages (cascades via FK).
#[frb]
pub fn ai_delete_conversation(conversation_id: String) -> Result<(), String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "DELETE FROM ai_conversations WHERE id = ?1",
                rusqlite::params![conversation_id],
            )?;
            Ok::<(), rusqlite::Error>(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Fetch all messages in a conversation, ordered by `created_at` ASC.
#[frb]
pub fn ai_get_messages(conversation_id: String) -> Vec<AiMessageDto> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, conversation_id, role, content, tokens_in, tokens_out, created_at
                 FROM ai_messages
                 WHERE conversation_id = ?1
                 ORDER BY created_at ASC",
            )?;
            let rows = stmt.query_map([&conversation_id], |row| {
                let role: String = row.get(2)?;
                Ok(AiMessageDto {
                    id: row.get(0)?,
                    conversation_id: row.get(1)?,
                    role: role_from_str(&role),
                    content: row.get(3)?,
                    tokens_in: row.get(4)?,
                    tokens_out: row.get(5)?,
                    created_at: row.get(6)?,
                })
            })?;
            rows.collect::<rusqlite::Result<Vec<_>>>()
        })
        .map_err(|e| e.to_string())
    })
    .unwrap_or_default()
}

/// Persist a user message before streaming starts. Returns the message DTO.
/// The assistant reply will be inserted separately by the streaming task
/// when the final chunk arrives.
#[frb]
pub fn ai_persist_user_message(
    conversation_id: String,
    content: String,
) -> Result<AiMessageDto, String> {
    let now = chrono::Utc::now().to_rfc3339();
    let dto = AiMessageDto {
        id: Uuid::new_v4().to_string(),
        conversation_id: conversation_id.clone(),
        role: MessageRole::User,
        content: content.clone(),
        tokens_in: None,
        tokens_out: None,
        created_at: now.clone(),
    };
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "INSERT INTO ai_messages (id, conversation_id, role, content, created_at)
                 VALUES (?1, ?2, 'user', ?3, ?4)",
                rusqlite::params![dto.id, conversation_id, content, now],
            )?;
            conn.execute(
                "UPDATE ai_conversations SET updated_at = ?1 WHERE id = ?2",
                rusqlite::params![now, conversation_id],
            )?;
            Ok::<(), rusqlite::Error>(())
        })
        .map_err(|e| e.to_string())
    })?;
    Ok(dto)
}

/// Persist a completed assistant reply. Callers invoke this from their
/// streaming-task finaliser once all chunks have been accumulated.
#[frb]
pub fn ai_persist_assistant_message(
    conversation_id: String,
    content: String,
    tokens_in: Option<i64>,
    tokens_out: Option<i64>,
) -> Result<AiMessageDto, String> {
    let now = chrono::Utc::now().to_rfc3339();
    let dto = AiMessageDto {
        id: Uuid::new_v4().to_string(),
        conversation_id: conversation_id.clone(),
        role: MessageRole::Assistant,
        content: content.clone(),
        tokens_in,
        tokens_out,
        created_at: now.clone(),
    };
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "INSERT INTO ai_messages
                   (id, conversation_id, role, content, tokens_in, tokens_out, created_at)
                 VALUES (?1, ?2, 'assistant', ?3, ?4, ?5, ?6)",
                rusqlite::params![
                    dto.id,
                    conversation_id,
                    content,
                    tokens_in,
                    tokens_out,
                    now,
                ],
            )?;
            conn.execute(
                "UPDATE ai_conversations SET updated_at = ?1 WHERE id = ?2",
                rusqlite::params![now, conversation_id],
            )?;
            Ok::<(), rusqlite::Error>(())
        })
        .map_err(|e| e.to_string())
    })?;
    let _ = role_to_str(&MessageRole::Assistant); // keep role_to_str referenced
    Ok(dto)
}

// ─── Streaming generation ─────────────────────────────────────────────────────

static STREAM_CANCELS: once_cell::sync::Lazy<
    dashmap::DashMap<String, tokio::sync::oneshot::Sender<()>>,
> = once_cell::sync::Lazy::new(Default::default);

static STREAM_CHUNKS: once_cell::sync::Lazy<
    dashmap::DashMap<String, std::sync::Mutex<Vec<AiChunkDto>>>,
> = once_cell::sync::Lazy::new(Default::default);

/// Send a user message; streaming chunks are delivered via a polling queue
/// keyed by `conversation_id` that Dart consumes via [poll_ai_chunks].
///
/// Returns the `message_id` assigned to the assistant reply so the Dart side
/// can correlate incoming chunk events. The call returns immediately; the
/// provider request runs on a detached task until completion or cancellation.
///
/// `terminal_context` contains the last N lines from the terminal scrollback.
#[frb]
pub async fn ai_send_message(
    conversation_id: String,
    content: String,
    config: AiProviderConfig,
    terminal_context: Option<String>,
) -> Result<String, String> {
    let message_id = Uuid::new_v4().to_string();
    let ctx = terminal_context
        .as_deref()
        .map(|raw| {
            let truncated = build_terminal_context(raw, config.context_lines as usize);
            redact_sensitive(&truncated)
        })
        .unwrap_or_default();
    let system = "You are Termex AI, an expert terminal assistant.".to_string();
    let user = if ctx.is_empty() {
        content.clone()
    } else {
        format!("Terminal context:\n```\n{ctx}\n```\n\n{content}")
    };
    let req = build_request(&config, system, user);

    let (tx, rx) = tokio::sync::oneshot::channel::<()>();
    STREAM_CANCELS.insert(conversation_id.clone(), tx);
    STREAM_CHUNKS.insert(conversation_id.clone(), std::sync::Mutex::new(Vec::new()));

    let conv_id = conversation_id.clone();
    let msg_id = message_id.clone();
    tokio::spawn(async move {
        let conv_for_chunks = conv_id.clone();
        let msg_for_chunks = msg_id.clone();
        let result = provider_client::stream(req, rx, move |delta, done| {
            let chunk = AiChunkDto {
                conversation_id: conv_for_chunks.clone(),
                message_id: msg_for_chunks.clone(),
                delta,
                done,
                tokens_in: None,
                tokens_out: None,
                error: None,
            };
            if let Some(buf) = STREAM_CHUNKS.get(&conv_for_chunks) {
                if let Ok(mut guard) = buf.lock() {
                    guard.push(chunk);
                }
            }
        })
        .await;
        if let Err(e) = result {
            if let Some(buf) = STREAM_CHUNKS.get(&conv_id) {
                if let Ok(mut guard) = buf.lock() {
                    guard.push(AiChunkDto {
                        conversation_id: conv_id.clone(),
                        message_id: msg_id.clone(),
                        delta: String::new(),
                        done: true,
                        tokens_in: None,
                        tokens_out: None,
                        error: Some(e),
                    });
                }
            }
        }
        STREAM_CANCELS.remove(&conv_id);
    });

    Ok(message_id)
}

/// Poll pending stream chunks for a conversation. Each call drains the buffer.
#[frb]
pub fn poll_ai_chunks(conversation_id: String) -> Vec<AiChunkDto> {
    if let Some(buf) = STREAM_CHUNKS.get(&conversation_id) {
        if let Ok(mut guard) = buf.lock() {
            return std::mem::take(&mut *guard);
        }
    }
    Vec::new()
}

/// Cancel an in-progress generation for a conversation.
#[frb]
pub fn ai_cancel_generation(conversation_id: String) {
    if let Some((_, tx)) = STREAM_CANCELS.remove(&conversation_id) {
        let _ = tx.send(());
    }
}

// ─── Command extraction ───────────────────────────────────────────────────────

/// Extract shell commands from an AI reply string.
/// Returns a list of command strings found in code blocks or inline code.
#[frb]
pub fn ai_extract_commands(text: String) -> Vec<String> {
    use regex::Regex;

    let mut commands = Vec::new();
    // Parse fenced code blocks: ```[lang]\n...\n```
    let mut in_block = false;
    let mut block_lines: Vec<&str> = Vec::new();
    for line in text.lines() {
        if line.starts_with("```") {
            if in_block {
                if !block_lines.is_empty() {
                    commands.push(block_lines.join("\n"));
                }
                block_lines.clear();
                in_block = false;
            } else {
                in_block = true;
            }
        } else if in_block {
            block_lines.push(line);
        }
    }

    // Inline code: `command` — only outside fenced blocks. Scan the original
    // text, but skip any run between matching triple backticks so we don't
    // double-count commands already captured above.
    let inline_re = Regex::new(r"`([^`\n]+)`").expect("valid regex");
    let mut scan = text.as_str();
    let mut inline_found: Vec<String> = Vec::new();
    while let Some(fence_start) = scan.find("```") {
        let before = &scan[..fence_start];
        for cap in inline_re.captures_iter(before) {
            inline_found.push(cap[1].trim().to_string());
        }
        match scan[fence_start + 3..].find("```") {
            Some(fence_end) => scan = &scan[fence_start + 3 + fence_end + 3..],
            None => scan = &scan[fence_start + 3..],
        }
    }
    for cap in inline_re.captures_iter(scan) {
        inline_found.push(cap[1].trim().to_string());
    }
    // Keep inline commands that look like shell invocations (contain a space
    // or a recognised command prefix) and aren't duplicates of fenced matches.
    for s in inline_found {
        if s.is_empty() || commands.iter().any(|c| c == &s) {
            continue;
        }
        commands.push(s);
    }
    commands
}

/// Check whether a command string contains potentially dangerous patterns.
#[frb]
pub fn ai_is_dangerous_command(command: String) -> bool {
    let danger_patterns = [
        "rm -rf",
        "rm -fr",
        ":(){ :|:& };:",
        "dd if=",
        "> /dev/sda",
        "mkfs",
        "chmod -R 777",
        "sudo rm",
        "shutdown",
        "reboot",
        "halt",
        "poweroff",
    ];
    let lower = command.to_lowercase();
    danger_patterns.iter().any(|p| lower.contains(p))
}

// ─── Provider config ──────────────────────────────────────────────────────────

/// Persist a provider configuration to the `settings` table. API keys are
/// stripped from the JSON blob and pushed to the OS keychain under
/// `termex:ai:apikey:{provider}` — matching the keychain convention used
/// elsewhere for SSH credentials.
#[frb]
pub fn ai_save_provider_config(config: AiProviderConfig) -> Result<(), String> {
    let key = format!("ai_provider_{}", provider_to_str(&config.provider));
    if let Some(ref k) = config.api_key {
        if !k.is_empty() {
            let kc_key =
                termex_core::keychain::ai_apikey_key(provider_to_str(&config.provider));
            termex_core::keychain::store(&kc_key, k)
                .map_err(|e| format!("failed to store API key: {e}"))?;
        }
    }
    let stored = AiProviderConfig {
        api_key: None,
        ..config
    };
    let json = serde_json::to_string(&stored).map_err(|e| e.to_string())?;
    let now = chrono::Utc::now().to_rfc3339();
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "INSERT INTO settings (key, value, updated_at) VALUES (?1, ?2, ?3)
                 ON CONFLICT(key) DO UPDATE SET
                     value = excluded.value,
                     updated_at = excluded.updated_at",
                rusqlite::params![key, json, now],
            )?;
            Ok::<(), rusqlite::Error>(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Load the saved provider configuration (returns None if not configured).
/// The API key is lazily loaded from the keychain on read.
#[frb]
pub fn ai_load_provider_config(provider: AiProvider) -> Option<AiProviderConfig> {
    let key = format!("ai_provider_{}", provider_to_str(&provider));
    let json: Option<String> = db_state::with_db(|db| {
        db.with_conn(|conn| {
            match conn.query_row::<String, _, _>(
                "SELECT value FROM settings WHERE key = ?1",
                rusqlite::params![key],
                |row| row.get(0),
            ) {
                Ok(v) => Ok(Some(v)),
                Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
                Err(e) => Err(e),
            }
        })
        .map_err(|e| e.to_string())
    })
    .ok()
    .flatten();

    let mut config: AiProviderConfig = serde_json::from_str(json.as_deref()?).ok()?;
    let kc_key = termex_core::keychain::ai_apikey_key(provider_to_str(&provider));
    config.api_key = termex_core::keychain::get(&kc_key).ok();
    Some(config)
}

/// Verify that the given API key is valid by making a minimal API call.
///
/// Uses a default model per-provider when the saved configuration is absent.
#[frb]
pub async fn ai_verify_api_key(provider: AiProvider, api_key: String) -> Result<bool, String> {
    let model = default_model_for(&provider).to_string();
    provider_client::verify(to_kind(&provider), api_key, None, model).await
}

/// Test whether a saved provider configuration is reachable.
#[frb]
pub async fn ai_test_provider_config(provider: AiProvider) -> Result<bool, String> {
    let config = ai_load_provider_config(provider.clone())
        .ok_or_else(|| format!("{} provider not configured", provider_to_str(&provider)))?;
    let api_key = config.api_key.unwrap_or_default();
    provider_client::verify(to_kind(&provider), api_key, config.base_url, config.model).await
}

fn default_model_for(p: &AiProvider) -> &'static str {
    match p {
        AiProvider::Claude => "claude-3-5-haiku-latest",
        AiProvider::OpenAi => "gpt-4o-mini",
        AiProvider::Ollama => "llama3.2",
        AiProvider::LocalLlama => "local",
    }
}

// ─── Conversation management (extended) ──────────────────────────────────────

/// Rename a conversation's title.
#[frb]
pub fn ai_rename_conversation(conversation_id: String, title: String) -> Result<(), String> {
    let now = chrono::Utc::now().to_rfc3339();
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let affected = conn.execute(
                "UPDATE ai_conversations SET title = ?1, updated_at = ?2 WHERE id = ?3",
                rusqlite::params![title, now, conversation_id],
            )?;
            if affected == 0 {
                return Err(rusqlite::Error::QueryReturnedNoRows);
            }
            Ok::<(), rusqlite::Error>(())
        })
        .map_err(|e| e.to_string())
    })
}

// ─── Single-shot AI calls ─────────────────────────────────────────────────────

/// Redact sensitive lines (passwords / passphrases) in terminal context.
fn redact_sensitive(text: &str) -> String {
    text.lines()
        .map(|line| {
            let lower = line.to_lowercase();
            if lower.contains("password:") || lower.contains("passphrase:") || lower.contains("password for") {
                "[REDACTED]"
            } else {
                line
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}

/// Truncate terminal context to [max_lines] lines, each at most 500 chars.
fn build_terminal_context(raw: &str, max_lines: usize) -> String {
    let lines: Vec<&str> = raw.lines().collect();
    let start = if lines.len() > max_lines { lines.len() - max_lines } else { 0 };
    lines[start..]
        .iter()
        .map(|line| {
            if line.len() > 500 {
                format!("{}[...截断]", &line[..500])
            } else {
                line.to_string()
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}

/// Build a provider request from the saved config + a prompt pair.
fn build_request(
    config: &AiProviderConfig,
    system_prompt: String,
    user_message: String,
) -> ProviderRequest {
    ProviderRequest {
        kind: to_kind(&config.provider),
        api_key: config.api_key.clone().unwrap_or_default(),
        base_url: config.base_url.clone(),
        model: config.model.clone(),
        system_prompt,
        user_message,
        max_tokens: 1024,
    }
}

/// Ask AI to explain a shell command.
///
/// `terminal_context` is the raw scrollback text. Sensitive lines are redacted
/// before being sent.  Returns the explanation as a plain string (non-streaming).
#[frb]
pub async fn ai_explain_command(
    command: String,
    terminal_context: Option<String>,
    config: AiProviderConfig,
) -> Result<String, String> {
    let ctx = terminal_context
        .as_deref()
        .map(|raw| {
            let truncated = build_terminal_context(raw, config.context_lines as usize);
            redact_sensitive(&truncated)
        })
        .unwrap_or_default();
    let system = "You are Termex AI, a terminal assistant. Explain shell commands \
                  concisely and identify dangerous flags. Answer in the user's language."
        .to_string();
    let user = if ctx.is_empty() {
        format!("Explain this command:\n```\n{command}\n```")
    } else {
        format!(
            "Terminal context:\n```\n{ctx}\n```\n\nExplain this command:\n```\n{command}\n```"
        )
    };
    provider_client::complete(build_request(&config, system, user)).await
}

/// Ask AI to diagnose a terminal error output.
///
/// Sensitive lines in `output` are redacted before being sent to the provider.
#[frb]
pub async fn ai_diagnose_error(
    output: String,
    command: Option<String>,
    config: AiProviderConfig,
) -> Result<String, String> {
    let safe_output = redact_sensitive(&output);
    let system = "You are Termex AI. Diagnose the following error output and \
                  propose a specific fix, including the exact command to run. \
                  Be terse; prefer concrete actions over explanation."
        .to_string();
    let user = match command {
        Some(cmd) => format!(
            "Command:\n```\n{cmd}\n```\n\nError output:\n```\n{safe_output}\n```"
        ),
        None => format!("Error output:\n```\n{safe_output}\n```"),
    };
    provider_client::complete(build_request(&config, system, user)).await
}

/// Convert a natural-language description to a list of candidate shell commands.
#[frb]
pub async fn ai_nl2cmd(
    description: String,
    os_hint: String,
    config: AiProviderConfig,
) -> Result<Vec<String>, String> {
    let system = format!(
        "You are Termex AI NL2Cmd. Output 1–5 shell commands that fulfil the \
         user's goal on {os_hint}. Output ONE command per line, no prose, no \
         numbering, no code fences. Prefer non-destructive commands."
    );
    let reply = provider_client::complete(build_request(&config, system, description)).await?;
    let commands: Vec<String> = reply
        .lines()
        .map(|l| l.trim_start_matches(|c: char| c.is_ascii_digit() || c == '.' || c == ')' || c.is_whitespace()))
        .map(|l| l.trim_matches('`').trim().to_string())
        .filter(|l| !l.is_empty())
        .take(5)
        .collect();
    Ok(commands)
}

/// Generate autocomplete suggestions for a partial command using AI.
///
/// Only called when other suggestion sources return no results (prefix length ≥ 4).
#[frb]
pub async fn ai_autocomplete(
    prefix: String,
    terminal_context: Option<String>,
    config: AiProviderConfig,
) -> Result<Vec<String>, String> {
    let ctx = terminal_context
        .as_deref()
        .map(|raw| build_terminal_context(raw, 5))
        .unwrap_or_default();
    let system = "You are a shell autocomplete engine. Given a partial command, \
                  propose up to 3 completions. Output ONE full command per line, \
                  no prose, no code fences."
        .to_string();
    let user = if ctx.is_empty() {
        format!("Partial: {prefix}")
    } else {
        format!("Recent terminal:\n{ctx}\n\nPartial: {prefix}")
    };
    let mut req = build_request(&config, system, user);
    req.max_tokens = 256;
    let reply = provider_client::complete(req).await?;
    Ok(reply
        .lines()
        .map(|l| l.trim_matches('`').trim().to_string())
        .filter(|l| !l.is_empty())
        .take(3)
        .collect())
}
