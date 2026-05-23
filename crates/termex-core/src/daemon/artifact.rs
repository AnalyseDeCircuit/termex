//! Structured artifacts emitted by AI CLIs via MCP.
//!
//! v0.71.1 introduces six standard `kind`s (diff / test_results /
//! file_tree / errors / warnings / summary) shared with the v0.73.0
//! mobile artifact viewers. Each kind has its own payload schema —
//! see `docs/iterations/v0.71.1-core-termexd-mcp-client.md` §2.7
//! for the wire-level contracts. The Rust side stores them as
//! free-form JSON so adding kinds doesn't require code changes
//! across the stack.

use serde::{Deserialize, Serialize};

/// Structured product emitted by an AI CLI during a task.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TaskArtifact {
    /// Unique id (uuid v4) so clients can reference the artifact
    /// independently of its position in any list.
    pub id: String,

    /// Task this artifact belongs to.
    pub task_id: String,

    /// One of the well-known kinds: `diff`, `test_results`,
    /// `file_tree`, `errors`, `warnings`, `summary`. Unknown kinds
    /// are forwarded as-is; the client side renders them via the
    /// fallback `_UnknownArtifact` widget.
    pub kind: String,

    /// Free-form JSON payload — schema depends on `kind`.
    pub payload: serde_json::Value,

    /// RFC3339 timestamp when the daemon recorded the artifact.
    pub created_at: String,
}

/// Lightweight summary used in card-preview situations where the
/// client only needs enough metadata to render a chip / item, not
/// the full payload. Full payload is fetched on-demand.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TaskArtifactSummary {
    pub id: String,
    pub task_id: String,
    pub kind: String,
    /// Approximate byte size of `payload` when serialized — UI uses
    /// this for "download full diff?" warnings on huge artifacts.
    pub size_bytes: u64,
    pub created_at: String,
    /// Optional one-line preview (kind-specific). E.g. for `diff` →
    /// "4 files changed, +120 −58"; for `test_results` → "22 passed".
    pub preview: Option<String>,
}
