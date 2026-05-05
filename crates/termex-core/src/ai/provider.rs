use async_trait::async_trait;
use serde::{Deserialize, Serialize};

/// A streaming chunk from an AI response.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AiChunk {
    pub text: String,
    pub done: bool,
}

/// Common request parameters for AI calls.
#[derive(Debug, Clone)]
pub struct AiRequest {
    pub system_prompt: String,
    pub user_message: String,
    pub max_tokens: u32,
}

/// Error type for AI provider operations.
#[derive(Debug, thiserror::Error)]
pub enum AiError {
    #[error("HTTP error: {0}")]
    Http(String),

    #[error("provider not configured")]
    NotConfigured,

    #[error("API error: {0}")]
    Api(String),

    #[error("parse error: {0}")]
    Parse(String),
}

/// AI provider trait — implemented by each backend (Claude, OpenAI, Ollama).
#[async_trait]
pub trait AiProvider: Send + Sync {
    /// Returns the provider name for display.
    fn name(&self) -> &str;

    /// Sends a request and returns the full response.
    async fn complete(&self, request: &AiRequest) -> Result<String, AiError>;

    /// Sends a request and streams response chunks via a callback.
    async fn stream(
        &self,
        request: &AiRequest,
        on_chunk: Box<dyn Fn(AiChunk) + Send>,
    ) -> Result<(), AiError>;
}

/// Configuration needed to create a provider instance.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProviderConfig {
    pub provider_type: String,
    pub api_key: String,
    pub api_base_url: Option<String>,
    pub model: String,
}