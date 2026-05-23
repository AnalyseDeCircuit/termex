//! Adapter tests: MCP notification → daemon ServerMessage variants.

#[path = "../src/mcp/mod.rs"]
#[allow(dead_code)]
mod mcp;

use serde_json::json;

use mcp::{mcp_notification_to_server_event, McpNotification};
use termex_core::daemon::ServerMessage;

#[test]
fn progress_maps_to_task_progress_clamped() {
    let m = McpNotification::Progress {
        progress: 1.5,
        message: Some("almost done".into()),
    };
    let evt = mcp_notification_to_server_event("t1", 7, m).unwrap();
    match evt {
        ServerMessage::TaskProgress {
            task_id,
            ratio,
            note,
            seq,
            ..
        } => {
            assert_eq!(task_id, "t1");
            assert_eq!(seq, 7);
            assert_eq!(ratio, 1.0);
            assert_eq!(note.as_deref(), Some("almost done"));
        }
        other => panic!("expected TaskProgress, got {other:?}"),
    }
}

#[test]
fn progress_with_negative_clamps_to_zero() {
    let m = McpNotification::Progress {
        progress: -0.5,
        message: None,
    };
    let evt = mcp_notification_to_server_event("t1", 1, m).unwrap();
    let ServerMessage::TaskProgress { ratio, .. } = evt else {
        panic!("wrong variant");
    };
    assert_eq!(ratio, 0.0);
}

#[test]
fn tool_use_start_maps_with_input_summary() {
    let m = McpNotification::ToolUseStart {
        tool: "edit_file".into(),
        input: json!({"path":"foo.rs","content":"a".repeat(500)}),
    };
    let evt = mcp_notification_to_server_event("t1", 3, m).unwrap();
    match evt {
        ServerMessage::TaskToolUse {
            tool,
            stage,
            input_summary,
            output_summary,
            ..
        } => {
            assert_eq!(tool, "edit_file");
            assert_eq!(stage, "start");
            assert!(input_summary.is_some());
            // Adapter caps the summary at 120 chars + ellipsis ('…',
            // 3 bytes UTF-8) → max ~123 bytes. Assert "much smaller
            // than the 500-byte raw input".
            let s = input_summary.as_ref().unwrap();
            assert!(s.chars().count() <= 121);
            assert!(s.ends_with('…'));
            assert!(output_summary.is_none());
        }
        other => panic!("got {other:?}"),
    }
}

#[test]
fn tool_use_complete_maps_with_output_summary() {
    let m = McpNotification::ToolUseComplete {
        tool: "edit_file".into(),
        output: json!("applied 3 hunks"),
    };
    let evt = mcp_notification_to_server_event("t1", 4, m).unwrap();
    match evt {
        ServerMessage::TaskToolUse {
            tool,
            stage,
            input_summary,
            output_summary,
            ..
        } => {
            assert_eq!(tool, "edit_file");
            assert_eq!(stage, "complete");
            assert!(input_summary.is_none());
            assert!(output_summary
                .as_deref()
                .map(|s| s.contains("applied 3 hunks"))
                .unwrap_or(false));
        }
        other => panic!("got {other:?}"),
    }
}

#[test]
fn artifact_maps_with_fresh_id() {
    let m = McpNotification::Artifact {
        kind: "diff".into(),
        payload: json!({"files":["a","b"]}),
    };
    let evt1 = mcp_notification_to_server_event("t1", 1, m.clone()).unwrap();
    let evt2 = mcp_notification_to_server_event("t1", 2, m).unwrap();
    let id_of = |e: &ServerMessage| match e {
        ServerMessage::TaskArtifact { artifact_id, .. } => artifact_id.clone(),
        _ => panic!("wrong variant"),
    };
    let id1 = id_of(&evt1);
    let id2 = id_of(&evt2);
    assert_ne!(id1, id2, "artifact ids must be fresh per event");
}

#[test]
fn wait_for_input_maps() {
    let m = McpNotification::WaitForInput {
        prompt: "approve?".into(),
        schema: Some(json!({"type":"boolean"})),
    };
    let evt = mcp_notification_to_server_event("t1", 5, m).unwrap();
    match evt {
        ServerMessage::TaskAwaitingInput {
            task_id,
            prompt,
            schema,
            ..
        } => {
            assert_eq!(task_id, "t1");
            assert_eq!(prompt, "approve?");
            assert!(schema.is_some());
        }
        other => panic!("got {other:?}"),
    }
}

#[test]
fn usage_maps_with_cost() {
    let m = McpNotification::Usage {
        input_tokens: 1000,
        output_tokens: 500,
        model: "claude-3.5-sonnet".into(),
        estimated_cost_usd: Some(0.012),
    };
    let evt = mcp_notification_to_server_event("t1", 9, m).unwrap();
    match evt {
        ServerMessage::TaskUsage {
            input_tokens,
            output_tokens,
            model,
            estimated_cost_usd,
            ..
        } => {
            assert_eq!(input_tokens, 1000);
            assert_eq!(output_tokens, 500);
            assert_eq!(model, "claude-3.5-sonnet");
            assert_eq!(estimated_cost_usd, Some(0.012));
        }
        other => panic!("got {other:?}"),
    }
}

#[test]
fn done_returns_none_handled_by_supervisor() {
    let m = McpNotification::Done {
        exit_code: Some(0),
        error: None,
    };
    let evt = mcp_notification_to_server_event("t1", 1, m);
    assert!(evt.is_none(), "Done is consumed by supervisor, not broadcast");
}

#[test]
fn unknown_returns_none_for_forward_compat() {
    let m = McpNotification::Unknown {
        method: "notifications/future_thing".into(),
    };
    let evt = mcp_notification_to_server_event("t1", 1, m);
    assert!(evt.is_none());
}
