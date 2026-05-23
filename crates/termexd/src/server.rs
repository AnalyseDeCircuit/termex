//! WebSocket server loop.
//!
//! Binds to `listen_addr`, accepts upgrades with bearer-token auth,
//! and routes each frame through [`handler::handle`].
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.2.
//!
//! Path versioning: only `/v1/stream` is accepted; everything else
//! returns 404 during the upgrade handshake.

use std::net::SocketAddr;
use std::sync::Arc;

use anyhow::{anyhow, Context};
use futures_util::{SinkExt, StreamExt};
use tokio::net::{TcpListener, TcpStream};
use tokio_tungstenite::tungstenite::handshake::server::{ErrorResponse, Request, Response};
use tokio_tungstenite::tungstenite::http::StatusCode;
use tokio_tungstenite::tungstenite::{Error as WsError, Message};
use tracing::{debug, info, warn};

use termex_core::daemon::{ClientMessage, ServerMessage};

use crate::auth;
use crate::handler::{self, HandlerCtx};

const WS_PATH: &str = "/v1/stream";
const AUTH_HEADER_PREFIX: &str = "Bearer ";

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

    // Inspect upgrade request: bearer token + /v1/stream path.
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

    while let Some(frame) = source.next().await {
        let frame = match frame {
            Ok(f) => f,
            Err(WsError::ConnectionClosed | WsError::AlreadyClosed) => break,
            Err(e) => return Err(anyhow!(e)),
        };

        let text = match frame {
            Message::Text(t) => t,
            Message::Binary(_) => continue, // we only speak JSON over text
            Message::Ping(p) => {
                sink.send(Message::Pong(p)).await?;
                continue;
            }
            Message::Pong(_) | Message::Frame(_) => continue,
            Message::Close(_) => break,
        };

        let response: ServerMessage = match serde_json::from_str::<ClientMessage>(&text) {
            Ok(msg) => handler::handle(&ctx, msg).await,
            Err(e) => ServerMessage::Response {
                request_id: "unknown".into(),
                ok: false,
                data: serde_json::Value::Null,
                error: Some(format!("parse error: {e}")),
                code: Some("ERR_BAD_REQUEST".into()),
            },
        };

        let payload =
            serde_json::to_string(&response).context("serialize response")?;
        sink.send(Message::Text(payload)).await?;
    }

    info!(?peer, "client disconnected");
    Ok(())
}
