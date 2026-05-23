//! Stdio framing for MCP: one JSON-RPC object per line.
//!
//! v0.71.1 uses the simple newline-delimited variant which is what
//! Claude Code's `--mcp-stdio` mode emits. Future MCP transports
//! (HTTP+SSE, WebSocket) plug in as separate modules.

use std::io;

use serde::de::DeserializeOwned;
use serde::Serialize;
use serde_json::Value;

use super::protocol::{JsonRpcNotification, JsonRpcResponse};

/// One frame on the inbound MCP stream. The CLI sends either a
/// response to a prior request (correlated by `id`) or an
/// unsolicited notification.
#[derive(Debug, Clone)]
pub enum InboundFrame {
    Response(JsonRpcResponse),
    Notification(JsonRpcNotification),
    /// JSON we couldn't classify (no `id` and no `method`) — we
    /// pass it up to the caller for logging / metrics but otherwise
    /// drop it.
    Unknown(Value),
}

/// Classify a parsed JSON value into one of the three inbound
/// frame variants.
pub fn classify(value: Value) -> InboundFrame {
    if value.get("id").is_some() && value.get("method").is_none() {
        match serde_json::from_value::<JsonRpcResponse>(value.clone()) {
            Ok(r) => InboundFrame::Response(r),
            Err(_) => InboundFrame::Unknown(value),
        }
    } else if value.get("method").is_some() && value.get("id").is_none() {
        match serde_json::from_value::<JsonRpcNotification>(value.clone()) {
            Ok(n) => InboundFrame::Notification(n),
            Err(_) => InboundFrame::Unknown(value),
        }
    } else {
        InboundFrame::Unknown(value)
    }
}

/// Encode a serializable JSON-RPC message into a single line ending
/// in `\n`. Returns the encoded bytes ready to write to the child's
/// stdin.
pub fn encode_line<T: Serialize>(msg: &T) -> io::Result<Vec<u8>> {
    let mut bytes =
        serde_json::to_vec(msg).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
    bytes.push(b'\n');
    Ok(bytes)
}

/// Parse a single JSON line into the typed envelope. The line should
/// already be `\n`-trimmed.
pub fn decode_line<T: DeserializeOwned>(line: &str) -> serde_json::Result<T> {
    serde_json::from_str(line)
}
