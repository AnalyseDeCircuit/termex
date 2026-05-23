//! `McpClient` — drives the JSON-RPC handshake + notification
//! stream over a child process's stdio.
//!
//! Usage from the supervisor:
//!
//! ```ignore
//! let stdin = pty_master.take_writer()?;
//! let stdout = BufReader::new(pty_master.try_clone_reader()?);
//! let mut client = McpClient::new(stdin, stdout);
//! match tokio::time::timeout(Duration::from_secs(2), client.handshake()).await {
//!     Ok(Ok(info)) => /* MCP mode */,
//!     _            => /* fall back to stdout adapter */,
//! }
//! ```

use std::io::{self, BufRead, Write};

use thiserror::Error;
use tracing::debug;

use super::handshake::{build_initialize_request, parse_initialize_result};
use super::protocol::{InitializeResult, McpNotification};
use super::transport::{classify, decode_line, encode_line, InboundFrame};

/// Errors from talking MCP to a child process.
#[derive(Debug, Error)]
pub enum McpError {
    #[error("handshake timeout after 2s")]
    HandshakeTimeout,

    #[error("protocol violation: {0}")]
    Protocol(String),

    #[error("transport io error: {0}")]
    Io(#[from] std::io::Error),

    #[error("json codec error: {0}")]
    Codec(#[from] serde_json::Error),

    #[error("server returned error: code={code} msg={message}")]
    ServerError { code: i32, message: String },

    #[error("stdin write closed")]
    StdinClosed,
}

/// Owns the child's stdin / stdout for MCP communication. Reads are
/// synchronous (we use `BufRead`) because the supervisor runs us on
/// a dedicated `std::thread::spawn` — see `supervisor::spawn`.
pub struct McpClient<W, R> {
    stdin: W,
    stdout: R,
    next_id: u64,
}

impl<W: Write, R: BufRead> McpClient<W, R> {
    pub fn new(stdin: W, stdout: R) -> Self {
        Self {
            stdin,
            stdout,
            next_id: 1,
        }
    }

    /// Send the `initialize` request and wait for the matching
    /// response. Returns the server's `InitializeResult` on
    /// success.
    ///
    /// Blocks the calling thread until a response arrives or stdin
    /// is closed. The supervisor wraps this in a tokio timeout, so
    /// CLIs that ignore MCP entirely don't stall the spawn.
    pub fn handshake(&mut self) -> Result<InitializeResult, McpError> {
        let id = self.alloc_id();
        let req = build_initialize_request(id);
        let bytes = encode_line(&req)?;
        self.stdin.write_all(&bytes).map_err(|_| McpError::StdinClosed)?;
        self.stdin.flush().ok();

        // Drain frames until we see the matching response. We
        // accept up to `MAX_PRELUDE_FRAMES` notifications before the
        // response since some CLIs emit progress events first.
        const MAX_PRELUDE_FRAMES: u32 = 16;
        let mut prelude = 0;
        loop {
            let frame = self.read_frame()?;
            match frame {
                InboundFrame::Response(resp) if resp.id == id => {
                    if let Some(err) = resp.error {
                        return Err(McpError::ServerError {
                            code: err.code,
                            message: err.message,
                        });
                    }
                    let result = resp.result.ok_or_else(|| {
                        McpError::Protocol("response missing result".into())
                    })?;
                    return parse_initialize_result(result).map_err(McpError::Codec);
                }
                InboundFrame::Response(_) => {
                    // Late response to a previous request — shouldn't
                    // happen during handshake but be lenient.
                    continue;
                }
                InboundFrame::Notification(_) | InboundFrame::Unknown(_) => {
                    prelude += 1;
                    if prelude > MAX_PRELUDE_FRAMES {
                        return Err(McpError::Protocol(
                            "too many frames before initialize response".into(),
                        ));
                    }
                }
            }
        }
    }

    /// Blocking iterator over inbound notifications. Yields one
    /// notification per call; returns `Ok(None)` on clean EOF and
    /// an error on transport / parse failure.
    pub fn next_notification(&mut self) -> Result<Option<McpNotification>, McpError> {
        loop {
            let frame = match self.read_frame_maybe_eof()? {
                Some(f) => f,
                None => return Ok(None),
            };
            match frame {
                InboundFrame::Notification(n) => {
                    let typed =
                        McpNotification::from_method(&n.method, n.params.as_ref().unwrap_or(&serde_json::Value::Null));
                    return Ok(Some(typed));
                }
                InboundFrame::Response(r) => {
                    debug!(id = r.id, "ignoring stray response during notification pump");
                }
                InboundFrame::Unknown(_) => {
                    debug!("ignoring unknown frame during notification pump");
                }
            }
        }
    }

    fn read_frame(&mut self) -> Result<InboundFrame, McpError> {
        self.read_frame_maybe_eof()?
            .ok_or_else(|| McpError::Protocol("EOF before frame".into()))
    }

    fn read_frame_maybe_eof(&mut self) -> Result<Option<InboundFrame>, McpError> {
        let mut line = String::new();
        loop {
            line.clear();
            let n = self.stdout.read_line(&mut line)?;
            if n == 0 {
                return Ok(None);
            }
            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }
            let value: serde_json::Value = match decode_line(trimmed) {
                Ok(v) => v,
                Err(_) => {
                    // Not JSON — could be banner text emitted before
                    // MCP starts. Skip rather than failing.
                    continue;
                }
            };
            return Ok(Some(classify(value)));
        }
    }

    fn alloc_id(&mut self) -> u64 {
        let id = self.next_id;
        self.next_id = id.checked_add(1).unwrap_or(1);
        id
    }
}

// Re-export a tiny marker so callers can sanity-check the linked
// version without pulling the whole module surface.
#[allow(dead_code)]
pub const MCP_CLIENT_VERSION: &str = env!("CARGO_PKG_VERSION");

#[allow(dead_code)]
fn _ensure_io_used() -> io::Result<()> {
    Ok(())
}
