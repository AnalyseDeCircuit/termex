//! Message router: turns a [`ClientMessage`] into a
//! [`ServerMessage::Response`] by dispatching to the appropriate
//! subsystem (DB / event bus / future supervisor).
//!
//! Kept synchronous-by-default with `async` only for the actual
//! subsystem awaits; this makes the routing logic trivially
//! exhaustive over the [`ClientMessage`] enum.
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.10.

use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use serde_json::json;
use tokio::sync::Mutex;
use uuid::Uuid;

use termex_core::daemon::{ClientMessage, ServerMessage};
use termex_core::task::{Task, TaskStatus};

use crate::db::Database;
use crate::error::DaemonError;
use crate::event_bus::EventBus;

/// Shared context the handler needs. Held in an Arc so the WS server
/// can hand it to each connection task.
pub struct HandlerCtx {
    pub db: Mutex<Database>,
    pub bus: EventBus,
}

impl HandlerCtx {
    pub fn new(db: Database, bus: EventBus) -> Arc<Self> {
        Arc::new(Self {
            db: Mutex::new(db),
            bus,
        })
    }
}

/// Route a single client message to its response.
///
/// v0.71.0 milestone — implements `task.assign` (skeleton: insert row,
/// no PTY spawn yet), `task.list`, `task.get`, `task.cancel` (db-only
/// status update), `task.decide` (auto-approve / mark cancelled),
/// `task.subscribe`/`unsubscribe` (no-op responses; the actual
/// subscription wiring happens in `server.rs` since it needs the
/// WebSocket sink), and `ping`.
///
/// PTY-aware behaviour lands in the supervisor commit.
pub async fn handle(ctx: &Arc<HandlerCtx>, msg: ClientMessage) -> ServerMessage {
    let request_id = msg.request_id().to_string();
    let result = route(ctx, msg).await;

    match result {
        Ok(data) => ServerMessage::Response {
            request_id,
            ok: true,
            data,
            error: None,
            code: None,
        },
        Err(e) => ServerMessage::Response {
            request_id,
            ok: false,
            data: serde_json::Value::Null,
            error: Some(e.to_string()),
            code: Some(e.code().to_string()),
        },
    }
}

/// Inner router that can use `?` because it explicitly returns a Result.
async fn route(
    ctx: &Arc<HandlerCtx>,
    msg: ClientMessage,
) -> Result<serde_json::Value, DaemonError> {
    match msg {
        ClientMessage::TaskAssign {
            ai_cli,
            prompt,
            workdir,
            idle_timeout_sec,
            ..
        } => {
            let task_id = Uuid::new_v4().to_string();
            let task = Task {
                id: task_id.clone(),
                ai_cli_kind: ai_cli,
                prompt,
                workdir,
                status: TaskStatus::Running, // v0.72.1 will branch on risk
                started_at: now_rfc3339(),
                ended_at: None,
                exit_code: None,
                idle_timeout_sec,
                output_tail: None,
                error: None,
            };
            ctx.db.lock().await.insert_task(&task)?;
            // Broadcast status (any future subscribers will see it).
            ctx.bus
                .broadcast(
                    &task_id,
                    ServerMessage::TaskStatus {
                        task_id: task_id.clone(),
                        status: TaskStatus::Running,
                        exit_code: None,
                        duration_ms: None,
                        ts_ms: now_ms(),
                    },
                )
                .await;
            Ok(json!({ "task_id": task_id }))
        }

        ClientMessage::TaskList { filter, .. } => {
            let tasks = ctx.db.lock().await.list_tasks(filter.status)?;
            Ok(json!({ "tasks": tasks }))
        }

        ClientMessage::TaskGet { task_id, .. } => {
            let task = ctx.db.lock().await.get_task(&task_id)?;
            Ok(json!({ "task": task }))
        }

        ClientMessage::TaskSubscribe { task_id, .. } => {
            // Actual subscription happens in server.rs when it sees
            // this message type (it has the WS sink). Here we just
            // ack so the round-trip works.
            Ok(json!({ "subscribed": task_id }))
        }

        ClientMessage::TaskUnsubscribe { task_id, .. } => Ok(json!({ "unsubscribed": task_id })),

        ClientMessage::TaskCancel { task_id, .. } => {
            // PTY-aware cancel lands with the supervisor commit;
            // milestone behaviour is DB-only.
            ctx.db.lock().await.update_status(
                &task_id,
                TaskStatus::Cancelled,
                Some(&now_rfc3339()),
                None,
                None,
            )?;
            ctx.bus
                .broadcast(
                    &task_id,
                    ServerMessage::TaskStatus {
                        task_id: task_id.clone(),
                        status: TaskStatus::Cancelled,
                        exit_code: None,
                        duration_ms: None,
                        ts_ms: now_ms(),
                    },
                )
                .await;
            Ok(serde_json::Value::Null)
        }

        ClientMessage::TaskDecide { task_id, .. } => {
            // v0.71.0 has no PendingConfirmation gating yet; treat
            // any decision as a no-op acknowledgement so v0.72.1's
            // client can probe daemon compatibility.
            let _ = task_id;
            Ok(serde_json::Value::Null)
        }

        ClientMessage::Ping { ts_ms, .. } => Ok(json!({ "echo_ts_ms": ts_ms })),
    }
}

fn now_rfc3339() -> String {
    chrono::Utc::now().to_rfc3339()
}

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}
