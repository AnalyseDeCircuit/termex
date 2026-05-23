//! MCP `initialize` handshake.
//!
//! Builds the JSON-RPC request and parses the typed result so the
//! caller can branch on capability negotiation.

use super::protocol::{
    ClientCapabilities, ClientInfo, InitializeParams, InitializeResult, JsonRpcRequest,
};

pub const MCP_PROTOCOL_VERSION: &str = "2025-01";

pub fn build_initialize_request(id: u64) -> JsonRpcRequest {
    let params = InitializeParams {
        protocol_version: MCP_PROTOCOL_VERSION.to_string(),
        capabilities: ClientCapabilities {
            events: true,
            artifacts: true,
        },
        client_info: ClientInfo {
            name: "termexd".into(),
            version: env!("CARGO_PKG_VERSION").to_string(),
        },
    };
    JsonRpcRequest {
        jsonrpc: "2.0".into(),
        id,
        method: "initialize".into(),
        params: Some(serde_json::to_value(params).unwrap()),
    }
}

pub fn parse_initialize_result(
    result: serde_json::Value,
) -> Result<InitializeResult, serde_json::Error> {
    serde_json::from_value(result)
}
