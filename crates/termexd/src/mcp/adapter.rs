//! Maps MCP notifications to daemon-side [`ServerMessage`] events
//! so they flow into the event bus alongside the legacy
//! `task.output` / `task.status` stream.

use std::time::{SystemTime, UNIX_EPOCH};

use uuid::Uuid;

use termex_core::daemon::ServerMessage;

use super::protocol::McpNotification;

/// Translate one MCP notification into the corresponding
/// [`ServerMessage`]. `seq` is the daemon-allocated monotonic
/// sequence used by v0.71.2's event replay.
///
/// Returns `None` for unknown / ignored notifications so the caller
/// can choose to log + drop without inflating the event stream.
pub fn mcp_notification_to_server_event(
    task_id: &str,
    seq: u64,
    note: McpNotification,
) -> Option<ServerMessage> {
    let ts_ms = now_ms();
    match note {
        McpNotification::Progress { progress, message } => Some(ServerMessage::TaskProgress {
            task_id: task_id.to_string(),
            ratio: progress.clamp(0.0, 1.0),
            note: message,
            seq,
            ts_ms,
        }),
        McpNotification::ToolUseStart { tool, input } => Some(ServerMessage::TaskToolUse {
            task_id: task_id.to_string(),
            tool,
            stage: "start".into(),
            input_summary: Some(summarize_value(&input, 120)),
            output_summary: None,
            seq,
            ts_ms,
        }),
        McpNotification::ToolUseComplete { tool, output } => Some(ServerMessage::TaskToolUse {
            task_id: task_id.to_string(),
            tool,
            stage: "complete".into(),
            input_summary: None,
            output_summary: Some(summarize_value(&output, 120)),
            seq,
            ts_ms,
        }),
        McpNotification::Artifact { kind, payload } => Some(ServerMessage::TaskArtifact {
            task_id: task_id.to_string(),
            artifact_id: Uuid::new_v4().to_string(),
            kind,
            payload,
            seq,
            ts_ms,
        }),
        McpNotification::WaitForInput { prompt, schema } => {
            Some(ServerMessage::TaskAwaitingInput {
                task_id: task_id.to_string(),
                prompt,
                schema,
                seq,
                ts_ms,
            })
        }
        McpNotification::Usage {
            input_tokens,
            output_tokens,
            model,
            estimated_cost_usd,
        } => Some(ServerMessage::TaskUsage {
            task_id: task_id.to_string(),
            input_tokens,
            output_tokens,
            model,
            estimated_cost_usd,
            seq,
            ts_ms,
        }),
        // Done is consumed by the supervisor directly (it drives
        // task lifecycle), not broadcast as its own event.
        McpNotification::Done { .. } => None,
        McpNotification::Unknown { .. } => None,
    }
}

/// Truncate a JSON value's debug repr to `max` chars. Used to keep
/// the daemon → client wire small even when an AI tool reads / writes
/// huge inputs.
fn summarize_value(v: &serde_json::Value, max: usize) -> String {
    let s = v.to_string();
    if s.len() <= max {
        s
    } else {
        let mut t = s.chars().take(max).collect::<String>();
        t.push('…');
        t
    }
}

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}
