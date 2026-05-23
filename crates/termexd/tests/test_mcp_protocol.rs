//! MCP protocol unit tests — JSON-RPC encode/decode + notification
//! method classification + handshake request shape.

#[path = "../src/mcp/mod.rs"]
#[allow(dead_code)]
mod mcp;

use mcp::protocol::{
    InitializeResult, JsonRpcNotification, JsonRpcRequest, JsonRpcResponse, McpNotification,
    ServerInfo,
};
use mcp::transport::{classify, decode_line, encode_line, InboundFrame};
use serde_json::json;

#[test]
fn classify_response_when_id_and_no_method() {
    let v = json!({"jsonrpc":"2.0","id":1,"result":{"foo":"bar"}});
    match classify(v) {
        InboundFrame::Response(r) => {
            assert_eq!(r.id, 1);
            assert!(r.result.is_some());
        }
        other => panic!("expected Response, got {other:?}"),
    }
}

#[test]
fn classify_notification_when_method_and_no_id() {
    let v = json!({"jsonrpc":"2.0","method":"notifications/progress",
        "params":{"progress":0.5}});
    match classify(v) {
        InboundFrame::Notification(n) => {
            assert_eq!(n.method, "notifications/progress");
        }
        other => panic!("expected Notification, got {other:?}"),
    }
}

#[test]
fn classify_unknown_when_neither_id_nor_method() {
    let v = json!({"jsonrpc":"2.0","banner":"hello"});
    matches!(classify(v), InboundFrame::Unknown(_));
}

#[test]
fn encode_line_appends_newline() {
    let req = JsonRpcRequest {
        jsonrpc: "2.0".into(),
        id: 7,
        method: "ping".into(),
        params: None,
    };
    let bytes = encode_line(&req).unwrap();
    assert_eq!(*bytes.last().unwrap(), b'\n');
}

#[test]
fn decode_line_round_trips_request() {
    let req = JsonRpcRequest {
        jsonrpc: "2.0".into(),
        id: 9,
        method: "init".into(),
        params: Some(json!({"k":"v"})),
    };
    let bytes = encode_line(&req).unwrap();
    let line = std::str::from_utf8(&bytes).unwrap().trim_end_matches('\n');
    let back: JsonRpcRequest = decode_line(line).unwrap();
    assert_eq!(back.id, 9);
    assert_eq!(back.method, "init");
}

#[test]
fn jsonrpc_response_error_round_trip() {
    let raw = r#"{"jsonrpc":"2.0","id":3,
        "error":{"code":-32000,"message":"bad","data":null}}"#;
    let parsed: JsonRpcResponse = serde_json::from_str(raw).unwrap();
    assert_eq!(parsed.id, 3);
    let err = parsed.error.unwrap();
    assert_eq!(err.code, -32000);
    assert_eq!(err.message, "bad");
}

#[test]
fn notification_from_method_progress() {
    let n = McpNotification::from_method(
        "notifications/progress",
        &json!({"progress":0.42,"message":"running tests"}),
    );
    match n {
        McpNotification::Progress { progress, message } => {
            assert!((progress - 0.42).abs() < 1e-6);
            assert_eq!(message.as_deref(), Some("running tests"));
        }
        other => panic!("expected Progress, got {other:?}"),
    }
}

#[test]
fn notification_from_method_artifact() {
    let n = McpNotification::from_method(
        "notifications/artifact",
        &json!({"kind":"diff","payload":{"files":["a","b"]}}),
    );
    match n {
        McpNotification::Artifact { kind, payload } => {
            assert_eq!(kind, "diff");
            assert_eq!(payload["files"][0], "a");
        }
        other => panic!("expected Artifact, got {other:?}"),
    }
}

#[test]
fn notification_from_method_usage_with_cost() {
    let n = McpNotification::from_method(
        "notifications/usage",
        &json!({
            "input_tokens": 1200,
            "output_tokens": 800,
            "model": "claude-3.5-sonnet",
            "estimated_cost_usd": 0.012
        }),
    );
    match n {
        McpNotification::Usage {
            input_tokens,
            output_tokens,
            model,
            estimated_cost_usd,
        } => {
            assert_eq!(input_tokens, 1200);
            assert_eq!(output_tokens, 800);
            assert_eq!(model, "claude-3.5-sonnet");
            assert_eq!(estimated_cost_usd, Some(0.012));
        }
        other => panic!("expected Usage, got {other:?}"),
    }
}

#[test]
fn notification_from_method_wait_for_input() {
    let n = McpNotification::from_method(
        "notifications/wait_for_input",
        &json!({"prompt":"OK to commit?","schema":{"type":"boolean"}}),
    );
    match n {
        McpNotification::WaitForInput { prompt, schema } => {
            assert_eq!(prompt, "OK to commit?");
            assert!(schema.is_some());
        }
        other => panic!("expected WaitForInput, got {other:?}"),
    }
}

#[test]
fn notification_from_method_done_with_exit() {
    let n = McpNotification::from_method(
        "notifications/done",
        &json!({"exit_code":0}),
    );
    match n {
        McpNotification::Done { exit_code, error } => {
            assert_eq!(exit_code, Some(0));
            assert!(error.is_none());
        }
        other => panic!("expected Done, got {other:?}"),
    }
}

#[test]
fn notification_from_method_unknown_forwards_compat() {
    let n = McpNotification::from_method("notifications/future_thing", &json!({"x":1}));
    match n {
        McpNotification::Unknown { method } => {
            assert_eq!(method, "notifications/future_thing");
        }
        other => panic!("expected Unknown, got {other:?}"),
    }
}

#[test]
fn handshake_request_shape() {
    let req = mcp::handshake::build_initialize_request(1);
    assert_eq!(req.jsonrpc, "2.0");
    assert_eq!(req.id, 1);
    assert_eq!(req.method, "initialize");
    let params = req.params.unwrap();
    assert_eq!(params["protocolVersion"], "2025-01");
    assert_eq!(params["clientInfo"]["name"], "termexd");
    assert_eq!(params["capabilities"]["events"], true);
    assert_eq!(params["capabilities"]["artifacts"], true);
}

#[test]
fn handshake_result_parses() {
    let v = json!({
        "protocolVersion":"2025-01",
        "capabilities":{"tools":[]},
        "serverInfo":{"name":"claude","version":"1.2.3"}
    });
    let r: InitializeResult = mcp::handshake::parse_initialize_result(v).unwrap();
    assert_eq!(r.server_info.name, "claude");
    assert_eq!(r.server_info.version, "1.2.3");
}

#[test]
fn notification_envelope_round_trip() {
    let n = JsonRpcNotification {
        jsonrpc: "2.0".into(),
        method: "notifications/progress".into(),
        params: Some(json!({"progress":1.0})),
    };
    let bytes = encode_line(&n).unwrap();
    let line = std::str::from_utf8(&bytes).unwrap().trim_end_matches('\n');
    let parsed: JsonRpcNotification = decode_line(line).unwrap();
    assert_eq!(parsed.method, "notifications/progress");
}

#[test]
fn server_info_serde_round_trip() {
    let s = ServerInfo {
        name: "x".into(),
        version: "0.1.0".into(),
    };
    let raw = serde_json::to_string(&s).unwrap();
    let back: ServerInfo = serde_json::from_str(&raw).unwrap();
    assert_eq!(back.name, "x");
    assert_eq!(back.version, "0.1.0");
}
