//! Tests for the daemon ⇄ client wire protocol.
//!
//! Wire stability tests: the JSON shape must not regress without
//! a protocol version bump, since older clients depend on it.

#![cfg(feature = "daemon")]

use termex_core::daemon::{
    AssignRequest, CancelSignal, ClientMessage, Decision, OutputStream, ServerMessage, TaskFilter,
};
use termex_core::task::{AiCliKind, TaskStatus};

#[test]
fn client_message_task_assign_wire_shape() {
    let msg = ClientMessage::TaskAssign {
        request_id: "req-1".into(),
        ai_cli: AiCliKind::ClaudeCode,
        prompt: "fix bug".into(),
        workdir: Some("/repo".into()),
        idle_timeout_sec: 30,
    };
    let v: serde_json::Value = serde_json::to_value(&msg).unwrap();
    assert_eq!(v["type"], "task.assign");
    assert_eq!(v["request_id"], "req-1");
    assert_eq!(v["ai_cli"], "claude_code");
    assert_eq!(v["prompt"], "fix bug");
    assert_eq!(v["workdir"], "/repo");
    assert_eq!(v["idle_timeout_sec"], 30);
}

#[test]
fn client_message_task_assign_workdir_omitted_when_none() {
    let msg = ClientMessage::TaskAssign {
        request_id: "req-2".into(),
        ai_cli: AiCliKind::Generic,
        prompt: "ls".into(),
        workdir: None,
        idle_timeout_sec: 30,
    };
    let json = serde_json::to_string(&msg).unwrap();
    assert!(!json.contains("workdir"), "Some-only field must skip None");
}

#[test]
fn client_message_request_id_accessor() {
    let cases = vec![
        ClientMessage::TaskList {
            request_id: "a".into(),
            filter: TaskFilter::default(),
        },
        ClientMessage::TaskGet {
            request_id: "b".into(),
            task_id: "t1".into(),
        },
        ClientMessage::TaskSubscribe {
            request_id: "c".into(),
            task_id: "t1".into(),
        },
        ClientMessage::TaskCancel {
            request_id: "d".into(),
            task_id: "t1".into(),
            signal: CancelSignal::Sigint,
        },
        ClientMessage::Ping {
            request_id: "e".into(),
            ts_ms: 0,
        },
    ];
    let ids: Vec<_> = cases.iter().map(|m| m.request_id()).collect();
    assert_eq!(ids, vec!["a", "b", "c", "d", "e"]);
}

#[test]
fn client_message_task_decide_wire_shape() {
    let msg = ClientMessage::TaskDecide {
        request_id: "req".into(),
        task_id: "t1".into(),
        decision: Decision::Approve,
    };
    let v: serde_json::Value = serde_json::to_value(&msg).unwrap();
    assert_eq!(v["type"], "task.decide");
    assert_eq!(v["decision"], "approve");
}

#[test]
fn server_message_response_wire_shape() {
    let ok = ServerMessage::Response {
        request_id: "r1".into(),
        ok: true,
        data: serde_json::json!({"task_id": "abc"}),
        error: None,
        code: None,
    };
    let v: serde_json::Value = serde_json::to_value(&ok).unwrap();
    assert_eq!(v["type"], "response");
    assert_eq!(v["ok"], true);
    assert_eq!(v["data"]["task_id"], "abc");
    assert!(v.get("error").is_none() || v["error"].is_null());

    let err = ServerMessage::Response {
        request_id: "r2".into(),
        ok: false,
        data: serde_json::Value::Null,
        error: Some("auth failed".into()),
        code: Some("ERR_AUTH".into()),
    };
    let v: serde_json::Value = serde_json::to_value(&err).unwrap();
    assert_eq!(v["ok"], false);
    assert_eq!(v["error"], "auth failed");
    assert_eq!(v["code"], "ERR_AUTH");
}

#[test]
fn server_message_task_output_wire_shape() {
    let m = ServerMessage::TaskOutput {
        task_id: "t1".into(),
        stream: OutputStream::Stdout,
        data: "hello\n".into(),
        seq: 42,
        ts_ms: 1234,
    };
    let v: serde_json::Value = serde_json::to_value(&m).unwrap();
    assert_eq!(v["type"], "task.output");
    assert_eq!(v["stream"], "stdout");
    assert_eq!(v["seq"], 42);
}

#[test]
fn server_message_task_status_wire_shape() {
    let m = ServerMessage::TaskStatus {
        task_id: "t1".into(),
        status: TaskStatus::Succeeded,
        exit_code: Some(0),
        duration_ms: Some(12345),
        seq: 7,
        ts_ms: 1,
    };
    let v: serde_json::Value = serde_json::to_value(&m).unwrap();
    assert_eq!(v["type"], "task.status");
    assert_eq!(v["status"], "succeeded");
    assert_eq!(v["exit_code"], 0);
    assert_eq!(v["duration_ms"], 12345);
    assert_eq!(v["seq"], 7);
}

#[test]
fn forward_compatible_unknown_type_rejected() {
    // Server must reject malformed messages (no `type` tag).
    let raw = r#"{"foo":"bar"}"#;
    let res: serde_json::Result<ClientMessage> = serde_json::from_str(raw);
    assert!(res.is_err(), "missing tag must fail");

    // Unknown type — strict tag matching must fail (clients should
    // never see daemon-side unknown types; if a newer daemon sends
    // newer types, older clients reject with error rather than
    // silently dropping).
    let raw = r#"{"type":"task.future_type_v2","request_id":"x"}"#;
    let res: serde_json::Result<ClientMessage> = serde_json::from_str(raw);
    assert!(res.is_err());
}

#[test]
fn assign_request_default() {
    let r = AssignRequest::default();
    assert_eq!(r.ai_cli, AiCliKind::Generic);
    assert_eq!(r.prompt, "");
    assert_eq!(r.idle_timeout_sec, 30);
    assert!(r.workdir.is_none());
}
