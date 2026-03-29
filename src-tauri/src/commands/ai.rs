use serde::Deserialize;
use tauri::{AppHandle, Emitter, State};

use crate::ai::danger::{DangerDetector, DangerResult};
use crate::crypto::aes;
use crate::keychain;
use crate::state::AppState;
use crate::storage::models::{AiProvider, ProviderType};

// ── AI Provider CRUD ──────────────────────────────────────────

/// Input for creating/updating an AI provider.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProviderInput {
    pub name: String,
    pub provider_type: String,
    pub api_key: Option<String>,
    pub api_base_url: Option<String>,
    pub model: String,
    #[serde(default = "default_max_tokens")]
    pub max_tokens: i32,
    #[serde(default = "default_temperature")]
    pub temperature: f64,
    pub is_default: bool,
}

fn default_max_tokens() -> i32 { 4096 }
fn default_temperature() -> f64 { 0.7 }

/// Lists all AI providers.
#[tauri::command]
pub fn ai_provider_list(state: State<'_, AppState>) -> Result<Vec<AiProvider>, String> {
    state
        .db
        .with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT id, name, provider_type, api_key_enc, api_base_url, model,
                        max_tokens, temperature, is_default, created_at, updated_at
                 FROM ai_providers ORDER BY is_default DESC, name",
            )?;
            let rows = stmt
                .query_map([], |row| {
                    let pt: String = row.get(2)?;
                    Ok(AiProvider {
                        id: row.get(0)?,
                        name: row.get(1)?,
                        provider_type: parse_provider_type(&pt),
                        api_key_enc: row.get(3)?,
                        api_base_url: row.get(4)?,
                        model: row.get(5)?,
                        max_tokens: row.get(6)?,
                        temperature: row.get(7)?,
                        is_default: row.get(8)?,
                        created_at: row.get(9)?,
                        updated_at: row.get(10)?,
                    })
                })?
                .filter_map(|r| r.ok())
                .collect();
            Ok(rows)
        })
        .map_err(|e| e.to_string())
}

/// Adds a new AI provider.
#[tauri::command]
pub fn ai_provider_add(
    state: State<'_, AppState>,
    input: ProviderInput,
) -> Result<AiProvider, String> {
    let id = uuid::Uuid::new_v4().to_string();
    let now = chrono::Utc::now().to_rfc3339();

    // Store API key in OS keychain
    let keychain_key = keychain::ai_apikey_key(&id);
    let api_key_keychain_id = if let Some(key) = input.api_key.as_deref().filter(|s| !s.is_empty()) {
        keychain::store(&keychain_key, key).ok();
        Some(keychain_key)
    } else {
        None
    };

    // If setting as default, unset other defaults
    if input.is_default {
        let _ = state.db.with_conn(|conn| {
            conn.execute("UPDATE ai_providers SET is_default = 0", [])?;
            Ok(())
        });
    }

    state
        .db
        .with_conn(|conn| {
            conn.execute(
                "INSERT INTO ai_providers (id, name, provider_type, api_key_keychain_id,
                    api_base_url, model, max_tokens, temperature, is_default, created_at, updated_at)
                 VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11)",
                rusqlite::params![
                    id,
                    input.name,
                    input.provider_type,
                    api_key_keychain_id,
                    input.api_base_url,
                    input.model,
                    input.max_tokens,
                    input.temperature,
                    input.is_default,
                    now,
                    now,
                ],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())?;

    Ok(AiProvider {
        id,
        name: input.name,
        provider_type: parse_provider_type(&input.provider_type),
        api_key_enc: None,
        api_base_url: input.api_base_url,
        model: input.model,
        max_tokens: input.max_tokens,
        temperature: input.temperature,
        is_default: input.is_default,
        created_at: now.clone(),
        updated_at: now,
    })
}

/// Updates an AI provider.
#[tauri::command]
pub fn ai_provider_update(
    state: State<'_, AppState>,
    id: String,
    input: ProviderInput,
) -> Result<(), String> {
    let now = chrono::Utc::now().to_rfc3339();

    // Update keychain API key if provided
    let keychain_key = keychain::ai_apikey_key(&id);
    let api_key_keychain_id = if let Some(key) = input.api_key.as_deref().filter(|s| !s.is_empty()) {
        keychain::store(&keychain_key, key).ok();
        Some(keychain_key)
    } else {
        None
    };

    if input.is_default {
        let _ = state.db.with_conn(|conn| {
            conn.execute("UPDATE ai_providers SET is_default = 0", [])?;
            Ok(())
        });
    }

    state
        .db
        .with_conn(|conn| {
            conn.execute(
                "UPDATE ai_providers SET name=?1, provider_type=?2,
                    api_key_keychain_id=COALESCE(?3, api_key_keychain_id), api_base_url=?4,
                    model=?5, max_tokens=?6, temperature=?7,
                    is_default=?8, updated_at=?9
                 WHERE id=?10",
                rusqlite::params![
                    input.name,
                    input.provider_type,
                    api_key_keychain_id,
                    input.api_base_url,
                    input.model,
                    input.max_tokens,
                    input.temperature,
                    input.is_default,
                    now,
                    id,
                ],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
}

/// Deletes an AI provider.
#[tauri::command]
pub fn ai_provider_delete(state: State<'_, AppState>, id: String) -> Result<(), String> {
    // Clean up keychain
    let _ = keychain::delete(&keychain::ai_apikey_key(&id));

    state
        .db
        .with_conn(|conn| {
            conn.execute(
                "DELETE FROM ai_providers WHERE id = ?1",
                rusqlite::params![id],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
}

/// Sets a provider as the default.
#[tauri::command]
pub fn ai_provider_set_default(state: State<'_, AppState>, id: String) -> Result<(), String> {
    state
        .db
        .with_conn(|conn| {
            conn.execute("UPDATE ai_providers SET is_default = 0", [])?;
            conn.execute(
                "UPDATE ai_providers SET is_default = 1 WHERE id = ?1",
                rusqlite::params![id],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
}

// ── Danger Detection ──────────────────────────────────────────

/// Checks a command for dangerous patterns (local regex detection).
#[tauri::command]
pub fn ai_check_danger(command: String) -> DangerResult {
    let detector = DangerDetector::new();
    detector.check(&command)
}

// ── Command Explanation ───────────────────────────────────────

/// Explains a command using the default AI provider.
/// Streams response chunks via `ai://explain/{request_id}` events.
#[tauri::command]
pub async fn ai_explain_command(
    state: State<'_, AppState>,
    app: AppHandle,
    command: String,
    request_id: String,
) -> Result<(), String> {
    // Load default provider config
    let provider_info = state
        .db
        .with_conn(|conn| {
            conn.query_row(
                "SELECT id, provider_type, api_key_enc, api_base_url, model
                 FROM ai_providers WHERE is_default = 1 LIMIT 1",
                [],
                |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, Option<Vec<u8>>>(2)?,
                        row.get::<_, Option<String>>(3)?,
                        row.get::<_, String>(4)?,
                    ))
                },
            )
        })
        .map_err(|_| "no default AI provider configured".to_string())?;

    let (pid, provider_type, api_key_enc, api_base_url, model) = provider_info;
    let api_key = resolve_api_key(&state, &pid, api_key_enc);

    let event = format!("ai://explain/{request_id}");
    let system = "You are a command-line expert. Explain what the given shell command does, step by step. Be concise and clear. Use the user's language.";
    let user_msg = format!("Explain this command:\n```\n{command}\n```");

    // Make HTTP request to the AI provider
    let response = call_ai_provider(
        &state,
        &provider_type,
        &api_key,
        api_base_url.as_deref(),
        &model,
        system,
        &user_msg,
        None,
    )
    .await
    .map_err(|e| e.to_string())?;

    // Emit the full response as a single chunk
    let _ = app.emit(
        &event,
        serde_json::json!({ "text": response, "done": true }),
    );

    Ok(())
}

// ── NL2Cmd ────────────────────────────────────────────────────

/// Converts a natural language description to a shell command.
/// Returns the generated command string.
#[tauri::command]
pub async fn ai_nl2cmd(
    state: State<'_, AppState>,
    app: AppHandle,
    description: String,
    context: NlContext,
    request_id: String,
) -> Result<(), String> {
    let provider_info = state
        .db
        .with_conn(|conn| {
            conn.query_row(
                "SELECT id, provider_type, api_key_enc, api_base_url, model
                 FROM ai_providers WHERE is_default = 1 LIMIT 1",
                [],
                |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, Option<Vec<u8>>>(2)?,
                        row.get::<_, Option<String>>(3)?,
                        row.get::<_, String>(4)?,
                    ))
                },
            )
        })
        .map_err(|_| "no default AI provider configured".to_string())?;

    let (pid, provider_type, api_key_enc, api_base_url, model) = provider_info;
    let api_key = resolve_api_key(&state, &pid, api_key_enc);

    let system = format!(
        "You are a shell command expert. Convert the user's natural language description into a shell command.\n\
         Context: OS={}, Shell={}, CWD={}\n\
         Rules:\n\
         - Output ONLY the command, no explanation\n\
         - If multiple commands are needed, join with && or ;\n\
         - Use common, portable commands when possible",
        context.os.as_deref().unwrap_or("Linux"),
        context.shell.as_deref().unwrap_or("bash"),
        context.cwd.as_deref().unwrap_or("~"),
    );

    let event = format!("ai://nl2cmd/{request_id}");

    let response = call_ai_provider(
        &state,
        &provider_type,
        &api_key,
        api_base_url.as_deref(),
        &model,
        &system,
        &description,
        None,
    )
    .await
    .map_err(|e| e.to_string())?;

    let _ = app.emit(
        &event,
        serde_json::json!({ "command": response.trim(), "done": true }),
    );

    Ok(())
}

/// Context information for NL2Cmd.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NlContext {
    pub os: Option<String>,
    pub shell: Option<String>,
    pub cwd: Option<String>,
}

/// Tests the connection to an AI provider.
#[tauri::command]
pub async fn ai_provider_test(
    state: State<'_, AppState>,
    id: String,
) -> Result<String, String> {
    let provider_info = state
        .db
        .with_conn(|conn| {
            conn.query_row(
                "SELECT provider_type, api_key_enc, api_base_url, model
                 FROM ai_providers WHERE id = ?1",
                rusqlite::params![id],
                |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, Option<Vec<u8>>>(1)?,
                        row.get::<_, Option<String>>(2)?,
                        row.get::<_, String>(3)?,
                    ))
                },
            )
        })
        .map_err(|e| e.to_string())?;

    let (provider_type, api_key_enc, api_base_url, model) = provider_info;
    let api_key = resolve_api_key(&state, &id, api_key_enc);

    let response = call_ai_provider(
        &state,
        &provider_type,
        &api_key,
        api_base_url.as_deref(),
        &model,
        "Reply with exactly: OK",
        "Test connection",
        Some(64),
    )
    .await?;

    Ok(response)
}

/// Returns the API key for an AI provider (from keychain or legacy).
#[tauri::command]
pub fn ai_provider_get_key(
    state: State<'_, AppState>,
    provider_id: String,
) -> Result<String, String> {
    // Try keychain first
    if let Ok(key) = keychain::get(&keychain::ai_apikey_key(&provider_id)) {
        return Ok(key);
    }

    // Fallback: legacy encrypted field
    let api_key_enc: Option<Vec<u8>> = state
        .db
        .with_conn(|conn| {
            conn.query_row(
                "SELECT api_key_enc FROM ai_providers WHERE id = ?1",
                rusqlite::params![provider_id],
                |row| row.get(0),
            )
        })
        .map_err(|e| e.to_string())?;

    let mk = state.master_key.read().expect("master_key lock poisoned");
    match (&*mk, api_key_enc) {
        (Some(key), Some(enc)) => {
            let plain = aes::decrypt(key, &enc).map_err(|e| e.to_string())?;
            String::from_utf8(plain).map_err(|e| e.to_string())
        }
        (None, Some(enc)) => String::from_utf8(enc).map_err(|e| e.to_string()),
        _ => Ok(String::new()),
    }
}

/// Tests AI provider connectivity using provided credentials directly (without saving).
#[tauri::command]
pub async fn ai_provider_test_direct(
    state: State<'_, AppState>,
    provider_type: String,
    api_key: String,
    api_base_url: Option<String>,
    model: String,
) -> Result<String, String> {
    // Local provider doesn't need connection test
    if provider_type == "local" {
        return Err("Local AI provider doesn't require connection test".to_string());
    }

    let response = call_ai_provider(
        &state,
        &provider_type,
        &api_key,
        api_base_url.as_deref(),
        &model,
        "Reply with exactly: OK",
        "Test connection",
        Some(64),
    )
    .await?;

    Ok(response)
}

// ── Internal Helpers ──────────────────────────────────────────

fn parse_provider_type(s: &str) -> ProviderType {
    match s {
        "claude" => ProviderType::Claude,
        "openai" => ProviderType::Openai,
        "gemini" => ProviderType::Gemini,
        "deepseek" => ProviderType::Deepseek,
        "ollama" => ProviderType::Ollama,
        "grok" => ProviderType::Grok,
        "mistral" => ProviderType::Mistral,
        "glm" => ProviderType::Glm,
        "minimax" => ProviderType::Minimax,
        "doubao" => ProviderType::Doubao,
        "local" => ProviderType::Local,
        _ => ProviderType::Custom,
    }
}

/// Resolves the API key for a provider: keychain first, then legacy DB field.
fn resolve_api_key(
    state: &State<'_, AppState>,
    provider_id: &str,
    api_key_enc: Option<Vec<u8>>,
) -> String {
    // Try keychain
    if let Ok(key) = keychain::get(&keychain::ai_apikey_key(provider_id)) {
        return key;
    }
    // Fallback: legacy encrypted field
    let mk = state.master_key.read().expect("master_key lock poisoned");
    match (&*mk, api_key_enc) {
        (Some(key), Some(enc)) => {
            aes::decrypt(key, &enc)
                .map(|p| String::from_utf8(p).unwrap_or_default())
                .unwrap_or_default()
        }
        (_, Some(enc)) => String::from_utf8(enc).unwrap_or_default(),
        _ => String::new(),
    }
}

/// Calls an AI provider's completion API.
async fn call_ai_provider(
    state: &AppState,
    provider_type: &str,
    api_key: &str,
    base_url: Option<&str>,
    model: &str,
    system: &str,
    user_message: &str,
    max_tokens: Option<i32>,
) -> Result<String, String> {
    let max_tok = max_tokens.unwrap_or(4096);
    let client = reqwest::Client::new();

    match provider_type {
        // Claude — uses Anthropic Messages API
        "claude" => {
            let url = format!(
                "{}/messages",
                base_url.unwrap_or("https://api.anthropic.com/v1")
            );
            let body = serde_json::json!({
                "model": model,
                "max_tokens": max_tok,
                "system": system,
                "messages": [
                    { "role": "user", "content": user_message },
                ],
            });
            let resp = client
                .post(&url)
                .header("x-api-key", api_key)
                .header("anthropic-version", "2023-06-01")
                .header("content-type", "application/json")
                .json(&body)
                .send()
                .await
                .map_err(|e| e.to_string())?;
            let json: serde_json::Value = resp.json().await.map_err(|e| e.to_string())?;
            if let Some(err) = json["error"]["message"].as_str() {
                return Err(err.to_string());
            }
            Ok(json["content"][0]["text"]
                .as_str()
                .unwrap_or("")
                .to_string())
        }
        // Gemini — uses Google Generative Language API
        "gemini" => {
            let url = format!(
                "{}/v1beta/models/{}:generateContent?key={}",
                base_url.unwrap_or("https://generativelanguage.googleapis.com"),
                model,
                api_key
            );
            let body = serde_json::json!({
                "system_instruction": { "parts": [{ "text": system }] },
                "contents": [{ "parts": [{ "text": user_message }] }],
            });
            let resp = client
                .post(&url)
                .header("content-type", "application/json")
                .json(&body)
                .send()
                .await
                .map_err(|e| e.to_string())?;
            let json: serde_json::Value = resp.json().await.map_err(|e| e.to_string())?;
            if let Some(err) = json["error"]["message"].as_str() {
                return Err(err.to_string());
            }
            Ok(json["candidates"][0]["content"]["parts"][0]["text"]
                .as_str()
                .unwrap_or("")
                .to_string())
        }
        // Local model via llama-server
        "local" => {
            let server = state.llama_server.read().await;
            let port = server
                .port
                .ok_or("Local AI engine is not running. Start it first.")?;
            drop(server);

            let url = format!("http://localhost:{}/v1/chat/completions", port);
            let body = serde_json::json!({
                "model": model,
                "messages": [
                    { "role": "system", "content": system },
                    { "role": "user", "content": user_message },
                ],
                "max_tokens": max_tok,
            });
            let resp = client
                .post(&url)
                .json(&body)
                .send()
                .await
                .map_err(|e| e.to_string())?;
            let json: serde_json::Value = resp.json().await.map_err(|e| e.to_string())?;
            if let Some(err) = json["error"]["message"].as_str() {
                return Err(err.to_string());
            }
            Ok(json["choices"][0]["message"]["content"]
                .as_str()
                .unwrap_or("")
                .to_string())
        }
        // Ollama — local REST API
        "ollama" => {
            let url = format!(
                "{}/api/generate",
                base_url.unwrap_or("http://localhost:11434")
            );
            let body = serde_json::json!({
                "model": model,
                "prompt": format!("{system}\n\n{user_message}"),
                "stream": false,
            });
            let resp = client
                .post(&url)
                .json(&body)
                .send()
                .await
                .map_err(|e| e.to_string())?;
            let json: serde_json::Value = resp.json().await.map_err(|e| e.to_string())?;
            Ok(json["response"].as_str().unwrap_or("").to_string())
        }
        // OpenAI-compatible: openai, deepseek, grok, mistral, glm, minimax, doubao, custom
        _ => {
            let default_base = match provider_type {
                "openai" => "https://api.openai.com/v1",
                "deepseek" => "https://api.deepseek.com/v1",
                "grok" => "https://api.x.ai/v1",
                "mistral" => "https://api.mistral.ai/v1",
                "glm" => "https://open.bigmodel.cn/api/paas/v4",
                "minimax" => "https://api.minimax.io/v1",
                "doubao" => "https://ark.cn-beijing.volces.com/api/v3",
                _ => "https://api.openai.com/v1",
            };
            let url = format!(
                "{}/chat/completions",
                base_url.unwrap_or(default_base)
            );
            let body = serde_json::json!({
                "model": model,
                "messages": [
                    { "role": "system", "content": system },
                    { "role": "user", "content": user_message },
                ],
                "max_tokens": max_tok,
            });
            let resp = client
                .post(&url)
                .header("Authorization", format!("Bearer {api_key}"))
                .json(&body)
                .send()
                .await
                .map_err(|e| e.to_string())?;
            let json: serde_json::Value = resp.json().await.map_err(|e| e.to_string())?;
            if let Some(err) = json["error"]["message"].as_str() {
                return Err(err.to_string());
            }
            Ok(json["choices"][0]["message"]["content"]
                .as_str()
                .unwrap_or("")
                .to_string())
        }
    }
}
