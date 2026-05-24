//! WebSocket server loop.
//!
//! Binds to `listen_addr`, accepts upgrades with bearer-token auth,
//! and routes each frame through [`handler::handle`].
//!
//! Subscription model: a single WS connection can subscribe to many
//! tasks. We fan all subscribed event streams in through a per-
//! connection mpsc into the single WS sink.
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.2.

use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;

use anyhow::{anyhow, Context};
use futures_util::{SinkExt, StreamExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::mpsc;
use tokio_tungstenite::tungstenite::handshake::server::{ErrorResponse, Request, Response};
use tokio_tungstenite::tungstenite::http::StatusCode;
use tokio_tungstenite::tungstenite::{Error as WsError, Message};
use tracing::{debug, info, warn};

use termex_core::daemon::{ClientMessage, ServerMessage};

use crate::auth;
use crate::handler::{self, HandlerCtx};

const WS_PATH: &str = "/v1/stream";
const AUTH_HEADER_PREFIX: &str = "Bearer ";
const SUBSCRIPTION_CHANNEL_CAP: usize = 256;

/// Run the WebSocket server. Returns when the listener errors out
/// (typically only on bind failure or process shutdown).
pub async fn run(
    listen_addr: &str,
    token: String,
    ctx: Arc<HandlerCtx>,
) -> anyhow::Result<()> {
    let listener = TcpListener::bind(listen_addr)
        .await
        .with_context(|| format!("bind {listen_addr}"))?;
    info!(addr = %listen_addr, "websocket server listening");

    loop {
        let (stream, peer) = match listener.accept().await {
            Ok(v) => v,
            Err(e) => {
                warn!(error = %e, "accept failed");
                continue;
            }
        };
        let ctx = ctx.clone();
        let token = token.clone();
        tokio::spawn(async move {
            if let Err(e) = handle_connection(stream, peer, token, ctx).await {
                debug!(?peer, error = %e, "connection ended");
            }
        });
    }
}

async fn handle_connection(
    stream: TcpStream,
    peer: SocketAddr,
    expected_token: String,
    ctx: Arc<HandlerCtx>,
) -> anyhow::Result<()> {
    debug!(?peer, "client connecting");

    let mut auth_ok = false;
    let mut path_ok = false;
    let ws_stream = tokio_tungstenite::accept_hdr_async(
        stream,
        |req: &Request, response: Response| {
            path_ok = req.uri().path() == WS_PATH;
            if let Some(authz) = req.headers().get("authorization") {
                if let Ok(s) = authz.to_str() {
                    if let Some(token) = s.strip_prefix(AUTH_HEADER_PREFIX) {
                        if auth::verify_token(&expected_token, token) {
                            auth_ok = true;
                        }
                    }
                }
            }
            if !path_ok {
                let mut resp = ErrorResponse::new(None);
                *resp.status_mut() = StatusCode::NOT_FOUND;
                return Err(resp);
            }
            if !auth_ok {
                let mut resp = ErrorResponse::new(None);
                *resp.status_mut() = StatusCode::UNAUTHORIZED;
                warn!(?peer, "auth rejected");
                return Err(resp);
            }
            Ok(response)
        },
    )
    .await?;

    info!(?peer, "client authenticated");

    let (mut sink, mut source) = ws_stream.split();

    // Fan-in channel for active subscriptions. Each `task.subscribe`
    // spawns a tokio task that pumps EventBus → this mpsc; the
    // outer select loop drains the mpsc into the WS sink.
    let (tx, mut rx) = mpsc::channel::<ServerMessage>(SUBSCRIPTION_CHANNEL_CAP);
    let mut subs: HashMap<String, tokio::task::JoinHandle<()>> = HashMap::new();

    // v0.74.2 — per-connection identity. Populated when the client
    // sends `client.register_device`; used as the `from_device` for
    // every subsequent handoff.* message so the runtime no longer
    // sees the "self" placeholder.
    let mut connection_device: Option<termex_core::daemon::DeviceWireDto> = None;
    // Wire the connection up to the handoff runtime so HandoffSend
    // can find this device's WS sink for `HandoffReceived` pushes.
    let device_sink: Arc<crate::handoff::WsSink> =
        Arc::new(crate::handoff::WsSink::new(tx.clone()));

    loop {
        tokio::select! {
            // Inbound frames
            maybe = source.next() => {
                let frame = match maybe {
                    Some(Ok(f)) => f,
                    Some(Err(WsError::ConnectionClosed | WsError::AlreadyClosed)) => break,
                    Some(Err(e)) => return Err(anyhow!(e)),
                    None => break,
                };

                let text = match frame {
                    Message::Text(t) => t,
                    Message::Binary(_) => continue,
                    Message::Ping(p) => {
                        sink.send(Message::Pong(p)).await?;
                        continue;
                    }
                    Message::Pong(_) | Message::Frame(_) => continue,
                    Message::Close(_) => break,
                };

                // Parse + inspect for subscription side-effects before
                // routing through the handler.
                let parsed: Result<ClientMessage, _> = serde_json::from_str(&text);
                let response: ServerMessage = match parsed {
                    Ok(msg) => {
                        // Side-effect: subscribe / unsubscribe + capture
                        // per-connection identity for handoff routing.
                        match &msg {
                            ClientMessage::TaskSubscribe { task_id, .. } => {
                                attach_subscription(
                                    task_id.clone(),
                                    ctx.clone(),
                                    tx.clone(),
                                    &mut subs,
                                ).await;
                                if let Some(dev) = &connection_device {
                                    ctx.handoff.subscribe(task_id, &dev.id).await;
                                }
                            }
                            ClientMessage::TaskUnsubscribe { task_id, .. } => {
                                if let Some(h) = subs.remove(task_id) {
                                    h.abort();
                                }
                                if let Some(dev) = &connection_device {
                                    ctx.handoff.unsubscribe(task_id, &dev.id).await;
                                }
                            }
                            ClientMessage::ClientRegisterDevice {
                                device_id,
                                name,
                                platform,
                                ..
                            } => {
                                // Stash identity for downstream handoff arms
                                // + connect this device's WS sink so
                                // HandoffSend can route messages back.
                                let dev = termex_core::daemon::DeviceWireDto {
                                    id: device_id.clone(),
                                    name: name.clone(),
                                    platform: platform.clone(),
                                };
                                if let Err(e) = ctx
                                    .handoff
                                    .on_connect(device_id, device_sink.clone())
                                    .await
                                {
                                    warn!(error = %e, "handoff on_connect failed");
                                }
                                connection_device = Some(dev);
                            }
                            _ => {}
                        }
                        // v0.74.2 — Server-side handoff intercept. We
                        // bypass the handler for these three messages
                        // because handler.rs uses a "self" placeholder
                        // for the from-device identity; here we have
                        // the real per-connection identity.
                        if let Some(resp) =
                            try_intercept_handoff(&ctx, &msg, &connection_device).await
                        {
                            resp
                        } else {
                            handler::handle(&ctx, msg).await
                        }
                    },
                    Err(e) => ServerMessage::Response {
                        request_id: "unknown".into(),
                        ok: false,
                        data: serde_json::Value::Null,
                        error: Some(format!("parse error: {e}")),
                        code: Some("ERR_BAD_REQUEST".into()),
                    },
                };

                let payload = serde_json::to_string(&response).context("serialize response")?;
                sink.send(Message::Text(payload)).await?;
            }

            // Subscribed task events
            Some(event) = rx.recv() => {
                let payload = serde_json::to_string(&event).context("serialize event")?;
                sink.send(Message::Text(payload)).await?;
            }
        }
    }

    // Cleanup: abort all subscription pump tasks + tell the handoff
    // runtime this device is now offline.
    for (_, h) in subs.drain() {
        h.abort();
    }
    if let Some(dev) = &connection_device {
        let touched = ctx.handoff.on_disconnect(&dev.id);
        debug!(device = %dev.id, watcher_tasks = ?touched, "handoff: client disconnected");
    }
    info!(?peer, "client disconnected");
    Ok(())
}

/// Server-side intercept for the 3 handoff messages whose handler
/// arm uses a "self" placeholder. Returns `Some(response)` when the
/// message was handled here; `None` falls through to the regular
/// handler (preserves the in-process test path that calls
/// `handler::handle` directly without a per-connection identity).
///
/// `pub(crate)` so integration tests can drive it without spinning
/// up a real WebSocket listener.
pub(crate) async fn try_intercept_handoff(
    ctx: &Arc<HandlerCtx>,
    msg: &ClientMessage,
    connection_device: &Option<termex_core::daemon::DeviceWireDto>,
) -> Option<ServerMessage> {
    let dev = match connection_device {
        Some(d) => d.clone(),
        None => return None,
    };

    use serde_json::json;
    use termex_core::handoff::TakeoverOutcome;

    match msg {
        ClientMessage::HandoffSend {
            request_id,
            task_id,
            target_device_id,
            deep_link,
        } => {
            let outcome = ctx
                .handoff
                .send_handoff(task_id, dev, target_device_id, deep_link)
                .await;
            let (ok, code, path) = match outcome {
                crate::handoff::DeliveryOutcome::DeliveredWs => (true, None, "ws"),
                crate::handoff::DeliveryOutcome::Offline => (true, None, "queued"),
                crate::handoff::DeliveryOutcome::UnknownTarget => {
                    (false, Some("ERR_NOT_FOUND".to_string()), "unknown")
                }
            };
            Some(ServerMessage::Response {
                request_id: request_id.clone(),
                ok,
                data: json!({ "delivered": ok, "delivery_path": path }),
                error: if ok { None } else {
                    Some(format!("unknown device: {target_device_id}"))
                },
                code,
            })
        }

        ClientMessage::HandoffTakeover {
            request_id,
            task_id,
            expected_previous_owner,
        } => {
            let result = ctx
                .handoff
                .try_take_over(task_id, &dev, expected_previous_owner.as_deref())
                .await;
            match result {
                Ok(TakeoverOutcome::Won { previous_owner_id }) => {
                    Some(ServerMessage::Response {
                        request_id: request_id.clone(),
                        ok: true,
                        data: json!({
                            "ok": true,
                            "previous_owner_id": previous_owner_id,
                        }),
                        error: None,
                        code: None,
                    })
                }
                Ok(TakeoverOutcome::RaceLost { actual_owner_id }) => {
                    Some(ServerMessage::Response {
                        request_id: request_id.clone(),
                        ok: false,
                        data: json!({
                            "actual_owner_id": actual_owner_id,
                        }),
                        error: Some("ownership changed concurrently".into()),
                        code: Some("OWNERSHIP_CHANGED".into()),
                    })
                }
                Err(e) => Some(ServerMessage::Response {
                    request_id: request_id.clone(),
                    ok: false,
                    data: serde_json::Value::Null,
                    error: Some(e.to_string()),
                    code: Some("ERR_INTERNAL".into()),
                }),
            }
        }

        ClientMessage::HandoffStateSync {
            request_id,
            task_id,
            ui_state,
        } => {
            let fanout = ctx
                .handoff
                .broadcast_state(task_id, dev, ui_state.clone());
            Some(ServerMessage::Response {
                request_id: request_id.clone(),
                ok: true,
                data: json!({ "fanout": fanout }),
                error: None,
                code: None,
            })
        }

        _ => None,
    }
}

/// Subscribe to a task on the EventBus and pipe its events into the
/// per-connection mpsc. If we already have a sub for this task, drop
/// the old one first (idempotent re-subscribe).
async fn attach_subscription(
    task_id: String,
    ctx: Arc<HandlerCtx>,
    tx: mpsc::Sender<ServerMessage>,
    subs: &mut HashMap<String, tokio::task::JoinHandle<()>>,
) {
    if let Some(old) = subs.remove(&task_id) {
        old.abort();
    }
    let mut rx = ctx.bus.subscribe(&task_id).await;
    let tx_clone = tx.clone();
    let task_id_clone = task_id.clone();
    let handle = tokio::spawn(async move {
        loop {
            match rx.recv().await {
                Ok(msg) => {
                    if tx_clone.send(msg).await.is_err() {
                        // Receiver dropped; client gone.
                        break;
                    }
                }
                Err(tokio::sync::broadcast::error::RecvError::Lagged(n)) => {
                    debug!(task = %task_id_clone, dropped = n, "subscription lagged");
                }
                Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
            }
        }
    });
    subs.insert(task_id, handle);
}
