//! `DaemonClient` — async SDK for talking to a remote termexd over a
//! WebSocket carried inside an SSH tunnel.
//!
//! v0.71.0 skeleton: connection / disconnection / request-response
//! correlation. Subscribe streams and full error taxonomy follow in
//! follow-up commits before v0.71.0 ships.
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.7.

use std::sync::Arc;
use std::time::Duration;

use thiserror::Error;
use tokio::sync::Mutex;

use super::protocol::{ClientMessage, ServerMessage};

/// Client-side errors. Bridge layer maps these to `Result<T, String>`
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
/// [`DaemonClient::connect`]; drop to disconnect.
///
/// Holding multiple `DaemonClient`s (one per remote server) is the
/// expected pattern — see `daemonConnectionProvider` in the Flutter
/// app.
#[derive(Clone)]
pub struct DaemonClient {
    inner: Arc<Mutex<ClientInner>>,
}

#[allow(dead_code)] // populated by follow-up commits
struct ClientInner {
    ws_url: String,
    token: String,
    // tx / rx halves of the WebSocket, populated in connect()
}

impl DaemonClient {
    /// Open a new WebSocket to `ws_url` and authenticate with `token`.
    ///
    /// The URL is typically `ws://127.0.0.1:<local_port>/v1/stream`
    /// where `local_port` is a forwarded port set up by the bridge's
    /// `daemon_connect_via_ssh` helper.
    pub async fn connect(ws_url: &str, token: &str) -> Result<Self, ClientError> {
        // v0.71.0 skeleton: connection wire-up follows in the
        // implementation commit. We construct the handle so the rest
        // of the SDK / bridge can be exercised against mock daemons
        // via DI.
        Ok(Self {
            inner: Arc::new(Mutex::new(ClientInner {
                ws_url: ws_url.to_string(),
                token: token.to_string(),
            })),
        })
    }

    /// Send a [`ClientMessage`] and wait for the matching
    /// [`ServerMessage::Response`]. Used internally by the typed
    /// helpers (`task_assign`, `task_list`, etc.).
    #[allow(dead_code, unused_variables)]
    async fn send_request(&self, msg: ClientMessage) -> Result<ServerMessage, ClientError> {
        // Skeleton — actual sink/stream wiring follows.
        Err(ClientError::Internal(
            "DaemonClient::send_request not yet wired".into(),
        ))
    }

    /// Gracefully close the connection.
    pub async fn close(self) -> Result<(), ClientError> {
        // Skeleton — no-op for v0.71.0 milestone.
        Ok(())
    }
}
