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

use termex_core::daemon::{CancelSignal, ClientMessage, DeviceWireDto, ServerMessage};
use termex_core::handoff::TakeoverOutcome;
use termex_core::task::{Task, TaskStatus};

use crate::db::Database;
use crate::error::DaemonError;
use crate::event_bus::EventBus;
use crate::event_log::EventLog;
use crate::handoff::{DeliveryOutcome, HandoffRuntime};
use crate::supervisor::{CancelKind, TaskSupervisor};

/// Shared context the handler needs. Held in an Arc so the WS server
/// can hand it to each connection task.
pub struct HandlerCtx {
    pub db: Arc<Mutex<Database>>,
    pub bus: EventBus,
    pub supervisor: TaskSupervisor,
    /// Optional event log for v0.71.2 replay. When None, `stream.replay`
    /// returns `{ replayed: 0 }` silently.
    pub event_log: Option<EventLog>,
    /// v0.74.2 — cross-device handoff runtime. Tracks connected
    /// devices, watcher sets, and ownership transitions.
    pub handoff: HandoffRuntime,
    /// When true, `task.assign` skips the PTY spawn step (DB-only
    /// behaviour). Used by tests to avoid forking real subprocesses.
    pub spawn_disabled: bool,
}

impl HandlerCtx {
    pub fn new(db: Database, bus: EventBus) -> Arc<Self> {
        let db = Arc::new(Mutex::new(db));
        let supervisor = TaskSupervisor::new(db.clone(), bus.clone());
        let event_log = EventLog::new(db.clone());
        bus.attach_event_log(event_log.clone());
        let handoff = HandoffRuntime::new(db.clone());
        Arc::new(Self {
            db,
            bus,
            supervisor,
            event_log: Some(event_log),
            handoff,
            spawn_disabled: false,
        })
    }

    /// Test-only constructor: `task.assign` still inserts the row
    /// and broadcasts the initial status, but no subprocess starts.
    /// Always public so integration tests (which can't see
    /// `cfg(test)` of the bin crate) can use it; behaviourally
    /// equivalent to `new` for everything except actual PTY spawn.
    pub fn new_no_spawn(db: Database, bus: EventBus) -> Arc<Self> {
        let db = Arc::new(Mutex::new(db));
        let supervisor = TaskSupervisor::new(db.clone(), bus.clone());
        let event_log = EventLog::new(db.clone());
        bus.attach_event_log(event_log.clone());
        let handoff = HandoffRuntime::new(db.clone());
        Arc::new(Self {
            db,
            bus,
            supervisor,
            event_log: Some(event_log),
            handoff,
            spawn_disabled: true,
        })
    }
}

fn cancel_signal_to_kind(s: CancelSignal) -> CancelKind {
    match s {
        CancelSignal::Sigint => CancelKind::Sigint,
        CancelSignal::Sigterm => CancelKind::Sigterm,
        CancelSignal::Sigkill => CancelKind::Sigkill,
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
                prompt: prompt.clone(),
                workdir: workdir.clone(),
                status: TaskStatus::Running, // v0.72.1 will branch on risk
                started_at: now_rfc3339(),
                ended_at: None,
                exit_code: None,
                idle_timeout_sec,
                output_tail: None,
                error: None,
            };
            ctx.db.lock().await.insert_task(&task)?;

            // Spawn the PTY subprocess unless the test harness has
            // disabled it.
            if !ctx.spawn_disabled {
                ctx.supervisor
                    .spawn(&task_id, ai_cli, &prompt, workdir.as_deref())
                    .await?;
            }

            // Broadcast initial status (any future subscribers will
            // see it; current subscribers wired in server.rs).
            let seq = ctx.bus.next_seq();
            ctx.bus
                .broadcast(
                    &task_id,
                    ServerMessage::TaskStatus {
                        task_id: task_id.clone(),
                        status: TaskStatus::Running,
                        exit_code: None,
                        duration_ms: None,
                        seq,
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

        ClientMessage::TaskCancel {
            task_id, signal, ..
        } => {
            // Try to signal the live PTY first. If the task isn't
            // active (e.g. it already finished), fall back to a
            // DB-only status flip so the user's intent is recorded.
            let supervisor_result = ctx
                .supervisor
                .cancel(&task_id, cancel_signal_to_kind(signal))
                .await;
            match supervisor_result {
                Ok(()) => {
                    // Waiter will broadcast the terminal status when
                    // the child actually exits; no extra event here.
                    Ok(serde_json::Value::Null)
                }
                Err(DaemonError::TaskNotFound(_)) => {
                    ctx.db.lock().await.update_status(
                        &task_id,
                        TaskStatus::Cancelled,
                        Some(&now_rfc3339()),
                        None,
                        None,
                    )?;
                    let seq = ctx.bus.next_seq();
                    ctx.bus
                        .broadcast(
                            &task_id,
                            ServerMessage::TaskStatus {
                                task_id: task_id.clone(),
                                status: TaskStatus::Cancelled,
                                exit_code: None,
                                duration_ms: None,
                                seq,
                                ts_ms: now_ms(),
                            },
                        )
                        .await;
                    Ok(serde_json::Value::Null)
                }
                Err(e) => Err(e),
            }
        }

        ClientMessage::TaskDecide { task_id, .. } => {
            // v0.71.0 has no PendingConfirmation gating yet; treat
            // any decision as a no-op acknowledgement so v0.72.1's
            // client can probe daemon compatibility.
            let _ = task_id;
            Ok(serde_json::Value::Null)
        }

        ClientMessage::Ping { ts_ms, .. } => Ok(json!({ "echo_ts_ms": ts_ms })),

        ClientMessage::ClientRegisterDevice {
            device_id,
            name,
            platform,
            push_token,
            push_platform,
            ..
        } => {
            ctx.handoff
                .register_device(
                    &device_id,
                    &name,
                    &platform,
                    push_token.as_deref(),
                    push_platform.as_deref(),
                )
                .await
                .map_err(|e| DaemonError::Internal(format!("handoff: {e}")))?;
            Ok(json!({ "device_id": device_id }))
        }

        ClientMessage::HandoffSend {
            task_id,
            target_device_id,
            deep_link,
            ..
        } => {
            // Resolve "from" identity from any device the caller
            // happens to have registered. Real wire calls carry
            // request-context auth that names the caller — for the
            // v0.74.2 skeleton we leave it as the target id's mirror
            // so the runtime decision (delivered vs offline) is
            // testable without that scaffolding.
            let from = DeviceWireDto {
                id: "self".into(),
                name: "self".into(),
                platform: "unknown".into(),
            };
            let outcome = ctx
                .handoff
                .send_handoff(&task_id, from, &target_device_id, &deep_link)
                .await;
            let path = match outcome {
                DeliveryOutcome::DeliveredWs => "ws",
                DeliveryOutcome::Offline => "queued",
                DeliveryOutcome::UnknownTarget => {
                    return Err(DaemonError::BadRequest(format!(
                        "unknown device: {target_device_id}"
                    )));
                }
            };
            Ok(json!({ "delivered": outcome == DeliveryOutcome::DeliveredWs,
                       "delivery_path": path }))
        }

        ClientMessage::HandoffTakeover {
            task_id,
            expected_previous_owner,
            ..
        } => {
            // Same identity caveat as HandoffSend — real wire pulls
            // this off the auth context. Skeleton uses a placeholder
            // so the ownership lock path is exercisable end-to-end.
            let new_owner = DeviceWireDto {
                id: "self".into(),
                name: "self".into(),
                platform: "unknown".into(),
            };
            let outcome = ctx
                .handoff
                .try_take_over(&task_id, &new_owner, expected_previous_owner.as_deref())
                .await
                .map_err(|e| DaemonError::Internal(format!("handoff: {e}")))?;
            match outcome {
                TakeoverOutcome::Won { previous_owner_id } => Ok(json!({
                    "ok": true,
                    "previous_owner_id": previous_owner_id,
                })),
                TakeoverOutcome::RaceLost { actual_owner_id } => Ok(json!({
                    "ok": false,
                    "code": "OWNERSHIP_CHANGED",
                    "actual_owner_id": actual_owner_id,
                })),
            }
        }

        ClientMessage::HandoffStateSync {
            task_id, ui_state, ..
        } => {
            let from = DeviceWireDto {
                id: "self".into(),
                name: "self".into(),
                platform: "unknown".into(),
            };
            let fanout = ctx.handoff.broadcast_state(&task_id, from, ui_state);
            Ok(json!({ "fanout": fanout }))
        }

        ClientMessage::StreamReplay {
            last_seq, limit, ..
        } => {
            // Replay-side effect: emit the matched events through the
            // event bus so the server.rs subscription pump streams
            // them back over the WS as normal task.* messages.
            //
            // We return the count via the Response; actual events
            // arrive after the response on the same connection.
            let log = match ctx.event_log.as_ref() {
                Some(l) => l,
                None => return Ok(json!({ "replayed": 0u64 })),
            };
            let events = log.replay_since(last_seq, limit as usize).await;
            let count = events.len() as u64;
            for ev in events {
                if let Some(task_id) = task_id_for_replay(&ev.message) {
                    ctx.bus.broadcast(&task_id, ev.message).await;
                }
            }
            Ok(json!({ "replayed": count }))
        }
    }
}

fn task_id_for_replay(msg: &ServerMessage) -> Option<String> {
    match msg {
        ServerMessage::TaskOutput { task_id, .. }
        | ServerMessage::TaskStatus { task_id, .. }
        | ServerMessage::TaskProgress { task_id, .. }
        | ServerMessage::TaskToolUse { task_id, .. }
        | ServerMessage::TaskArtifact { task_id, .. }
        | ServerMessage::TaskAwaitingInput { task_id, .. }
        | ServerMessage::TaskUsage { task_id, .. } => Some(task_id.clone()),
        _ => None,
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
