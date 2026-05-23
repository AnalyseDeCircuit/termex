//! McpClient handshake tests against in-memory pipe pairs.
//!
//! We don't fork a real CLI here — we feed scripted JSON-RPC
//! responses through an in-memory Read implementation and capture
//! what the client writes. This lets us exercise the protocol layer
//! deterministically.

#[path = "../src/mcp/mod.rs"]
#[allow(dead_code)]
mod mcp;

use std::io::{BufReader, Cursor, Write};
use std::sync::{Arc, Mutex};

use serde_json::json;

use mcp::client::{McpClient, McpError};

/// Writer that captures everything pushed to it for inspection.
#[derive(Clone, Default)]
struct CapturingWriter(Arc<Mutex<Vec<u8>>>);

impl Write for CapturingWriter {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        self.0.lock().unwrap().extend_from_slice(buf);
        Ok(buf.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

impl CapturingWriter {
    fn drain_string(&self) -> String {
        let mut g = self.0.lock().unwrap();
        let s = String::from_utf8(g.clone()).unwrap();
        g.clear();
        s
    }
}

fn server_response_line(id: u64, server: &str, version: &str) -> String {
    json!({
        "jsonrpc":"2.0",
        "id": id,
        "result": {
            "protocolVersion": "2025-01",
            "capabilities": {},
            "serverInfo": {"name": server, "version": version}
        }
    })
    .to_string()
        + "\n"
}

#[test]
fn handshake_succeeds_with_immediate_response() {
    let response = server_response_line(1, "claude", "1.2.3");
    let reader = BufReader::new(Cursor::new(response));
    let writer = CapturingWriter::default();
    let mut client = McpClient::new(writer.clone(), reader);
    let info = client.handshake().expect("handshake ok");
    assert_eq!(info.server_info.name, "claude");
    assert_eq!(info.server_info.version, "1.2.3");

    // Verify we actually wrote an initialize request.
    let written = writer.drain_string();
    assert!(written.contains("\"method\":\"initialize\""));
    assert!(written.contains("\"id\":1"));
    assert!(written.ends_with('\n'));
}

#[test]
fn handshake_tolerates_prelude_notifications() {
    let mut feed = String::new();
    // 3 random notifications before the response.
    for _ in 0..3 {
        feed.push_str(&format!(
            "{}\n",
            json!({"jsonrpc":"2.0","method":"notifications/banner","params":{}})
        ));
    }
    feed.push_str(&server_response_line(1, "codex", "2.0"));
    let reader = BufReader::new(Cursor::new(feed));
    let writer = CapturingWriter::default();
    let mut client = McpClient::new(writer, reader);
    let info = client.handshake().unwrap();
    assert_eq!(info.server_info.name, "codex");
}

#[test]
fn handshake_skips_banner_text_before_json() {
    let mut feed = String::new();
    feed.push_str("Claude Code v1.2.3 starting...\n");
    feed.push_str("ready.\n\n");
    feed.push_str(&server_response_line(1, "claude", "1.2.3"));
    let reader = BufReader::new(Cursor::new(feed));
    let writer = CapturingWriter::default();
    let mut client = McpClient::new(writer, reader);
    let info = client.handshake().unwrap();
    assert_eq!(info.server_info.name, "claude");
}

#[test]
fn handshake_fails_on_server_error_response() {
    let bad = json!({
        "jsonrpc":"2.0","id":1,
        "error":{"code":-32601,"message":"method not found"}
    })
    .to_string()
        + "\n";
    let reader = BufReader::new(Cursor::new(bad));
    let writer = CapturingWriter::default();
    let mut client = McpClient::new(writer, reader);
    let err = client.handshake().unwrap_err();
    matches!(err, McpError::ServerError { .. });
    if let McpError::ServerError { code, message } = err {
        assert_eq!(code, -32601);
        assert_eq!(message, "method not found");
    }
}

#[test]
fn handshake_fails_on_eof_before_response() {
    let reader = BufReader::new(Cursor::new(""));
    let writer = CapturingWriter::default();
    let mut client = McpClient::new(writer, reader);
    let err = client.handshake().unwrap_err();
    matches!(err, McpError::Protocol(_));
}

#[test]
fn handshake_fails_on_too_many_prelude_frames() {
    // > 16 unrelated notifications -> protocol violation.
    let mut feed = String::new();
    for _ in 0..40 {
        feed.push_str(&format!(
            "{}\n",
            json!({"jsonrpc":"2.0","method":"notifications/banner","params":{}})
        ));
    }
    let reader = BufReader::new(Cursor::new(feed));
    let writer = CapturingWriter::default();
    let mut client = McpClient::new(writer, reader);
    let err = client.handshake().unwrap_err();
    matches!(err, McpError::Protocol(_));
}

#[test]
fn notification_pump_yields_typed_progress() {
    let mut feed = server_response_line(1, "claude", "1.0.0");
    feed.push_str(&format!(
        "{}\n",
        json!({"jsonrpc":"2.0","method":"notifications/progress","params":{"progress":0.5}})
    ));
    feed.push_str(&format!(
        "{}\n",
        json!({"jsonrpc":"2.0","method":"notifications/done","params":{"exit_code":0}})
    ));
    let reader = BufReader::new(Cursor::new(feed));
    let writer = CapturingWriter::default();
    let mut client = McpClient::new(writer, reader);
    let _info = client.handshake().unwrap();

    let n1 = client.next_notification().unwrap().expect("progress");
    matches!(n1, mcp::McpNotification::Progress { .. });

    let n2 = client.next_notification().unwrap().expect("done");
    matches!(n2, mcp::McpNotification::Done { .. });

    let n3 = client.next_notification().unwrap();
    assert!(n3.is_none(), "EOF should yield None");
}

#[test]
fn notification_pump_ignores_stray_responses() {
    let mut feed = server_response_line(1, "claude", "1.0.0");
    // Stray late response with different id
    feed.push_str(&format!(
        "{}\n",
        json!({"jsonrpc":"2.0","id":99,"result":{}})
    ));
    // Then a progress
    feed.push_str(&format!(
        "{}\n",
        json!({"jsonrpc":"2.0","method":"notifications/progress","params":{"progress":1.0}})
    ));
    let reader = BufReader::new(Cursor::new(feed));
    let writer = CapturingWriter::default();
    let mut client = McpClient::new(writer, reader);
    client.handshake().unwrap();
    let n = client.next_notification().unwrap().unwrap();
    matches!(n, mcp::McpNotification::Progress { .. });
}
