//! JSON-RPC 2.0 + MCP message types we care about.
//!
//! We only model client-side initiate + the inbound notifications we
//! act on. Anything else from the AI CLI (resource listings, tool
//! schemas, etc.) is ignored.

use serde::{Deserialize, Serialize};
use serde_json::Value;

// ─── JSON-RPC 2.0 base ───────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcRequest {
    pub jsonrpc: String, // "2.0"
    pub id: u64,
    pub method: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub params: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcResponse {
    pub jsonrpc: String,
    pub id: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<JsonRpcError>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcError {
    pub code: i32,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcNotification {
    pub jsonrpc: String,
    pub method: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub params: Option<Value>,
}

// ─── Handshake ───────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InitializeParams {
    #[serde(rename = "protocolVersion")]
    pub protocol_version: String,
    pub capabilities: ClientCapabilities,
    #[serde(rename = "clientInfo")]
    pub client_info: ClientInfo,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ClientCapabilities {
    #[serde(default)]
    pub events: bool,
    #[serde(default)]
    pub artifacts: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClientInfo {
    pub name: String,
    pub version: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InitializeResult {
    #[serde(rename = "protocolVersion")]
    pub protocol_version: String,
    #[serde(default)]
    pub capabilities: Value,
    #[serde(rename = "serverInfo")]
    pub server_info: ServerInfo,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerInfo {
    pub name: String,
    pub version: String,
}

// ─── Inbound notifications ───────────────────────────────────────

/// MCP notifications the daemon listens for. Variants we don't care
/// about parse as [`McpNotification::Unknown`] so we forward-compat
/// silently.
#[derive(Debug, Clone)]
pub enum McpNotification {
    Progress {
        progress: f32,
        message: Option<String>,
    },
    ToolUseStart {
        tool: String,
        input: Value,
    },
    ToolUseComplete {
        tool: String,
        output: Value,
    },
    Artifact {
        kind: String,
        payload: Value,
    },
    WaitForInput {
        prompt: String,
        schema: Option<Value>,
    },
    Usage {
        input_tokens: u64,
        output_tokens: u64,
        model: String,
        estimated_cost_usd: Option<f64>,
    },
    Done {
        exit_code: Option<i32>,
        error: Option<String>,
    },
    Unknown {
        method: String,
    },
}

impl McpNotification {
    /// Parse the `method + params` pair from an incoming JSON-RPC
    /// notification into our typed enum.
    pub fn from_method(method: &str, params: &Value) -> Self {
        match method {
            "notifications/progress" => Self::Progress {
                progress: params["progress"].as_f64().unwrap_or(0.0) as f32,
                message: params["message"].as_str().map(str::to_owned),
            },
            "notifications/tool_use_start" => Self::ToolUseStart {
                tool: params["tool"].as_str().unwrap_or_default().to_string(),
                input: params["input"].clone(),
            },
            "notifications/tool_use_complete" => Self::ToolUseComplete {
                tool: params["tool"].as_str().unwrap_or_default().to_string(),
                output: params["output"].clone(),
            },
            "notifications/artifact" => Self::Artifact {
                kind: params["kind"].as_str().unwrap_or("unknown").to_string(),
                payload: params["payload"].clone(),
            },
            "notifications/wait_for_input" => Self::WaitForInput {
                prompt: params["prompt"].as_str().unwrap_or_default().to_string(),
                schema: params
                    .get("schema")
                    .filter(|v| !v.is_null())
                    .cloned(),
            },
            "notifications/usage" => Self::Usage {
                input_tokens: params["input_tokens"].as_u64().unwrap_or(0),
                output_tokens: params["output_tokens"].as_u64().unwrap_or(0),
                model: params["model"].as_str().unwrap_or_default().to_string(),
                estimated_cost_usd: params["estimated_cost_usd"].as_f64(),
            },
            "notifications/done" => Self::Done {
                exit_code: params["exit_code"].as_i64().map(|n| n as i32),
                error: params["error"].as_str().map(str::to_owned),
            },
            other => Self::Unknown {
                method: other.to_string(),
            },
        }
    }
}
