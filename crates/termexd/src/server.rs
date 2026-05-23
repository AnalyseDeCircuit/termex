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
                        // Side-effect: subscribe / unsubscribe.
                        match &msg {
                            ClientMessage::TaskSubscribe { task_id, .. } => {
                                attach_subscription(
                                    task_id.clone(),
                                    ctx.clone(),
                                    tx.clone(),
                                    &mut subs,
                                ).await;
                            }
                            ClientMessage::TaskUnsubscribe { task_id, .. } => {
                                if let Some(h) = subs.remove(task_id) {
                                    h.abort();
                                }
                            }
                            _ => {}
                        }
                        handler::handle(&ctx, msg).await
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

    // Cleanup: abort all subscription pump tasks.
    for (_, h) in subs.drain() {
        h.abort();
    }
    info!(?peer, "client disconnected");
    Ok(())
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
