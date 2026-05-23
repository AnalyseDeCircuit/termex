//! `DaemonClient` — async SDK for talking to a remote termexd over a
//! WebSocket carried inside an SSH tunnel.
//!
//! Connection model:
//! * A single tokio task owns the WS connection (sink + stream).
//! * That task reads frames and demultiplexes:
//!     - `Response { request_id, .. }` → routed to the matching
//!       oneshot held in `pending`.
//!     - `task.output / task.status / pong / future-typed events` →
//!       fanned out via per-task broadcast channels in `streams`.
//! * The public API speaks `Result<…, ClientError>` and never holds
//!   the WS connection across `.await` points — only the inner task
//!   touches the socket, so cancelled futures don't poison anything.
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.7.

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;

use futures_util::{SinkExt, StreamExt};
use thiserror::Error;
use tokio::sync::{broadcast, mpsc, oneshot, Mutex};
use tokio_tungstenite::tungstenite::client::IntoClientRequest;
use tokio_tungstenite::tungstenite::http::Request;
use tokio_tungstenite::tungstenite::Message;
use uuid::Uuid;

use crate::task::Task;

use super::protocol::{
    AssignRequest, CancelSignal, ClientMessage, Decision, ServerMessage, TaskFilter,
};

const DEFAULT_REQUEST_TIMEOUT: Duration = Duration::from_secs(15);
const SUBSCRIBE_CHANNEL_CAPACITY: usize = 256;
const COMMAND_QUEUE_CAPACITY: usize = 128;

/// Client-side errors. The bridge layer maps these to `Result<T, String>`
/// at the FFI boundary.
#[derive(Debug, Error)]
pub enum ClientError {
    #[error("connection failed: {0}")]
    Connect(String),

    #[error("daemon returned error: code={code} message={message}")]
    Daemon { code: String, message: String },

    #[error("request timeout after {0:?}")]
    Timeout(Duration),

    #[error("connection closed unexpectedly")]
    Closed,

    #[error("serialize/deserialize error: {0}")]
    Codec(#[from] serde_json::Error),

    #[error("internal: {0}")]
    Internal(String),
}

/// Async SDK for a single termexd connection. Construct with
/// [`DaemonClient::connect`]; clone freely (cheap Arc) and drop the
/// last clone to disconnect.
#[derive(Clone)]
pub struct DaemonClient {
    inner: Arc<ClientInner>,
}

struct ClientInner {
    cmd_tx: mpsc::Sender<OutboundCommand>,
    next_request_id: AtomicU64,
}

/// Commands the public API sends to the connection task.
enum OutboundCommand {
    Send(ClientMessage, oneshot::Sender<ServerMessage>),
    Subscribe(String, oneshot::Sender<broadcast::Receiver<ServerMessage>>),
    Close,
}

impl DaemonClient {
    /// Open a new WebSocket to `ws_url` and authenticate with `token`.
    ///
    /// The URL is typically `ws://127.0.0.1:<local_port>/v1/stream`
    /// where `local_port` is a forwarded port set up by the bridge's
    /// `daemon_connect_via_ssh` helper.
    pub async fn connect(ws_url: &str, token: &str) -> Result<Self, ClientError> {
        let mut req: Request<()> = ws_url
            .into_client_request()
            .map_err(|e| ClientError::Connect(format!("bad url: {e}")))?;
        req.headers_mut().insert(
            "authorization",
            format!("Bearer {token}")
                .parse()
                .map_err(|e| ClientError::Connect(format!("bad token: {e}")))?,
        );

        let (ws_stream, _resp) = tokio_tungstenite::connect_async(req)
            .await
            .map_err(|e| ClientError::Connect(e.to_string()))?;

        let (cmd_tx, cmd_rx) = mpsc::channel(COMMAND_QUEUE_CAPACITY);
        tokio::spawn(connection_task(ws_stream, cmd_rx));

        Ok(Self {
            inner: Arc::new(ClientInner {
                cmd_tx,
                next_request_id: AtomicU64::new(1),
            }),
        })
    }

    fn next_request_id(&self) -> String {
        let n = self.inner.next_request_id.fetch_add(1, Ordering::SeqCst);
        format!("req-{n}")
    }

    /// Assign a task. Returns the daemon-generated task id.
    pub async fn task_assign(&self, req: AssignRequest) -> Result<String, ClientError> {
        let msg = ClientMessage::TaskAssign {
            request_id: self.next_request_id(),
            ai_cli: req.ai_cli,
            prompt: req.prompt,
            workdir: req.workdir,
            idle_timeout_sec: req.idle_timeout_sec,
        };
        let resp = self.send_with_timeout(msg, DEFAULT_REQUEST_TIMEOUT).await?;
        let data = unwrap_response(resp)?;
        let task_id = data["task_id"]
            .as_str()
            .ok_or_else(|| ClientError::Internal("task_id missing".into()))?;
        Ok(task_id.to_string())
    }

    pub async fn task_list(&self, filter: TaskFilter) -> Result<Vec<Task>, ClientError> {
        let msg = ClientMessage::TaskList {
            request_id: self.next_request_id(),
            filter,
        };
        let resp = self.send_with_timeout(msg, DEFAULT_REQUEST_TIMEOUT).await?;
        let data = unwrap_response(resp)?;
        let tasks: Vec<Task> = serde_json::from_value(data["tasks"].clone())?;
        Ok(tasks)
    }

    pub async fn task_get(&self, task_id: &str) -> Result<Option<Task>, ClientError> {
        let msg = ClientMessage::TaskGet {
            request_id: self.next_request_id(),
            task_id: task_id.to_string(),
        };
        let resp = self.send_with_timeout(msg, DEFAULT_REQUEST_TIMEOUT).await?;
        let data = unwrap_response(resp)?;
        let task: Option<Task> = serde_json::from_value(data["task"].clone())?;
        Ok(task)
    }

    pub async fn task_cancel(
        &self,
        task_id: &str,
        signal: CancelSignal,
    ) -> Result<(), ClientError> {
        let msg = ClientMessage::TaskCancel {
            request_id: self.next_request_id(),
            task_id: task_id.to_string(),
            signal,
        };
        let resp = self.send_with_timeout(msg, DEFAULT_REQUEST_TIMEOUT).await?;
        let _data = unwrap_response(resp)?;
        Ok(())
    }

    /// v0.72.1 PendingConfirmation flow — present here for API
    /// completeness; v0.71.0 daemon ignores the decision.
    pub async fn task_decide(
        &self,
        task_id: &str,
        decision: Decision,
    ) -> Result<(), ClientError> {
        let msg = ClientMessage::TaskDecide {
            request_id: self.next_request_id(),
            task_id: task_id.to_string(),
            decision,
        };
        let resp = self.send_with_timeout(msg, DEFAULT_REQUEST_TIMEOUT).await?;
        let _data = unwrap_response(resp)?;
        Ok(())
    }

    /// Subscribe to events for `task_id`. The returned receiver
    /// yields every [`ServerMessage`] the daemon broadcasts for that
    /// task. Drop the receiver to unsubscribe (the daemon-side sub
    /// stays alive until the daemon connection closes; an explicit
    /// `task.unsubscribe` is a future enhancement).
    pub async fn subscribe(
        &self,
        task_id: &str,
    ) -> Result<broadcast::Receiver<ServerMessage>, ClientError> {
        // 1. Tell the connection task to register a local broadcaster
        //    BEFORE we send the daemon subscription, so we don't
        //    race incoming events.
        let (tx, rx) = oneshot::channel();
        self.inner
            .cmd_tx
            .send(OutboundCommand::Subscribe(task_id.to_string(), tx))
            .await
            .map_err(|_| ClientError::Closed)?;
        let receiver = rx.await.map_err(|_| ClientError::Closed)?;

        // 2. Send the daemon-side task.subscribe.
        let msg = ClientMessage::TaskSubscribe {
            request_id: self.next_request_id(),
            task_id: task_id.to_string(),
        };
        let resp = self.send_with_timeout(msg, DEFAULT_REQUEST_TIMEOUT).await?;
        let _ = unwrap_response(resp)?;

        Ok(receiver)
    }

    /// Round-trip a custom client message with timeout.
    async fn send_with_timeout(
        &self,
        msg: ClientMessage,
        timeout: Duration,
    ) -> Result<ServerMessage, ClientError> {
        let (tx, rx) = oneshot::channel();
        self.inner
            .cmd_tx
            .send(OutboundCommand::Send(msg, tx))
            .await
            .map_err(|_| ClientError::Closed)?;
        match tokio::time::timeout(timeout, rx).await {
            Ok(Ok(resp)) => Ok(resp),
            Ok(Err(_)) => Err(ClientError::Closed),
            Err(_) => Err(ClientError::Timeout(timeout)),
        }
    }

    /// Gracefully close the connection.
    pub async fn close(self) -> Result<(), ClientError> {
        let _ = self.inner.cmd_tx.send(OutboundCommand::Close).await;
        Ok(())
    }
}

/// Pull a successful Response.data out, or return Daemon error.
fn unwrap_response(msg: ServerMessage) -> Result<serde_json::Value, ClientError> {
    match msg {
        ServerMessage::Response {
            ok,
            data,
            error,
            code,
            ..
        } => {
            if ok {
                Ok(data)
            } else {
                Err(ClientError::Daemon {
                    code: code.unwrap_or_else(|| "ERR_UNKNOWN".into()),
                    message: error.unwrap_or_else(|| "no error message".into()),
                })
            }
        }
        other => Err(ClientError::Internal(format!(
            "expected Response, got {other:?}"
        ))),
    }
}

/// Background task that owns the WebSocket connection. Receives
/// commands over an mpsc, multiplexes outbound frames, and
/// demultiplexes inbound frames into the pending request map +
/// per-task subscription broadcasts.
async fn connection_task<S>(
    ws: tokio_tungstenite::WebSocketStream<S>,
    mut cmd_rx: mpsc::Receiver<OutboundCommand>,
) where
    S: tokio::io::AsyncRead + tokio::io::AsyncWrite + Unpin + Send + 'static,
{
    let (mut sink, mut source) = ws.split();
    let pending: Arc<Mutex<HashMap<String, oneshot::Sender<ServerMessage>>>> =
        Arc::new(Mutex::new(HashMap::new()));
    let subs: Arc<Mutex<HashMap<String, broadcast::Sender<ServerMessage>>>> =
        Arc::new(Mutex::new(HashMap::new()));

    loop {
        tokio::select! {
            // Commands from the public API
            cmd = cmd_rx.recv() => {
                let Some(cmd) = cmd else { break };
                match cmd {
                    OutboundCommand::Send(msg, responder) => {
                        let request_id = msg.request_id().to_string();
                        let payload = match serde_json::to_string(&msg) {
                            Ok(s) => s,
                            Err(e) => {
                                let _ = responder.send(make_error_response(
                                    &request_id,
                                    "ERR_INTERNAL",
                                    &format!("serialize: {e}"),
                                ));
                                continue;
                            }
                        };
                        pending.lock().await.insert(request_id.clone(), responder);
                        if sink.send(Message::Text(payload)).await.is_err() {
                            // Connection lost — fail all pending.
                            let mut pend = pending.lock().await;
                            for (_, tx) in pend.drain() {
                                let _ = tx.send(make_error_response(
                                    "unknown", "ERR_WS", "connection closed",
                                ));
                            }
                            break;
                        }
                    }
                    OutboundCommand::Subscribe(task_id, responder) => {
                        let mut s = subs.lock().await;
                        let tx = s
                            .entry(task_id.clone())
                            .or_insert_with(|| broadcast::channel(SUBSCRIBE_CHANNEL_CAPACITY).0);
                        let _ = responder.send(tx.subscribe());
                    }
                    OutboundCommand::Close => {
                        let _ = sink.send(Message::Close(None)).await;
                        break;
                    }
                }
            }

            // Frames from the daemon
            frame = source.next() => {
                let Some(frame) = frame else { break };
                let Ok(frame) = frame else { break };
                let text = match frame {
                    Message::Text(t) => t,
                    Message::Ping(p) => {
                        let _ = sink.send(Message::Pong(p)).await;
                        continue;
                    }
                    Message::Close(_) => break,
                    _ => continue,
                };
                let parsed: Result<ServerMessage, _> = serde_json::from_str(&text);
                let msg = match parsed {
                    Ok(m) => m,
                    Err(_) => continue,
                };
                match &msg {
                    ServerMessage::Response { request_id, .. } => {
                        let mut pend = pending.lock().await;
                        if let Some(tx) = pend.remove(request_id) {
                            let _ = tx.send(msg);
                        }
                    }
                    ServerMessage::TaskOutput { task_id, .. }
                    | ServerMessage::TaskStatus { task_id, .. }
                    | ServerMessage::TaskProgress { task_id, .. }
                    | ServerMessage::TaskToolUse { task_id, .. }
                    | ServerMessage::TaskArtifact { task_id, .. }
                    | ServerMessage::TaskAwaitingInput { task_id, .. }
                    | ServerMessage::TaskUsage { task_id, .. } => {
                        let s = subs.lock().await;
                        if let Some(tx) = s.get(task_id) {
                            let _ = tx.send(msg);
                        }
                    }
                    ServerMessage::Pong { .. } => {
                        // No-op for now; v0.71.2's keepalive will use this.
                    }
                }
            }
        }
    }

    // Drain pending requests with a Closed error so callers wake up.
    let mut pend = pending.lock().await;
    for (request_id, tx) in pend.drain() {
        let _ = tx.send(make_error_response(
            &request_id,
            "ERR_WS",
            "connection closed",
        ));
    }
}

fn make_error_response(request_id: &str, code: &str, message: &str) -> ServerMessage {
    ServerMessage::Response {
        request_id: request_id.to_string(),
        ok: false,
        data: serde_json::Value::Null,
        error: Some(message.to_string()),
        code: Some(code.to_string()),
    }
}

/// Helper for callers that just want a fresh request id (e.g. when
/// building raw `ClientMessage` variants the typed helpers don't
/// cover). Currently unused but exposed for future-proofing the API.
#[allow(dead_code)]
fn fresh_request_id() -> String {
    format!("req-{}", Uuid::new_v4().simple())
}
