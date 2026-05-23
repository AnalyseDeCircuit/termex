//! Unified daemon error type. Maps to wire-level error codes.
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.10.

use thiserror::Error;

#[derive(Debug, Error)]
pub enum DaemonError {
    #[error("authentication failed: {0}")]
    Auth(String),

    #[error("task not found: {0}")]
    TaskNotFound(String),

    #[error("PTY spawn failed: {0}")]
    PtySpawn(String),

    #[error("PTY io error: {0}")]
    PtyIo(#[from] std::io::Error),

    #[error("database error: {0}")]
    Db(#[from] rusqlite::Error),

    #[error("WebSocket error: {0}")]
    Ws(#[from] tokio_tungstenite::tungstenite::Error),

    #[error("protocol violation: {0}")]
    Protocol(String),

    #[error("invalid request: {0}")]
    BadRequest(String),

    #[error("internal: {0}")]
    Internal(String),
}

impl DaemonError {
    /// Stable error code exposed on the wire so clients can branch on
    /// failure modes without parsing the human-readable message.
    pub fn code(&self) -> &'static str {
        match self {
            Self::Auth(_) => "ERR_AUTH",
            Self::TaskNotFound(_) => "ERR_NOT_FOUND",
            Self::PtySpawn(_) => "ERR_PTY_SPAWN",
            Self::PtyIo(_) => "ERR_PTY_IO",
            Self::Db(_) => "ERR_DB",
            Self::Ws(_) => "ERR_WS",
            Self::Protocol(_) => "ERR_PROTOCOL",
            Self::BadRequest(_) => "ERR_BAD_REQUEST",
            Self::Internal(_) => "ERR_INTERNAL",
        }
    }
}
