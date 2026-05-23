//! MCP (Model Context Protocol) client for Claude Code / Codex CLIs.
//!
//! v0.71.1 — implements the subset of MCP needed to observe an AI
//! CLI's progress / artifacts / token usage. We are strictly a
//! client / observer; we don't expose tools or resources back to
//! the AI side.
//!
//! See `docs/iterations/v0.71.1-core-termexd-mcp-client.md`.

pub mod adapter;
pub mod client;
pub mod handshake;
pub mod protocol;
pub mod transport;

pub use adapter::mcp_notification_to_server_event;
pub use client::{McpClient, McpError};
pub use protocol::{McpNotification, ServerInfo};
