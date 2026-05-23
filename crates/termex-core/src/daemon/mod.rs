//! Daemon client SDK + shared wire protocol DTOs.
//!
//! Enabled by the `daemon` cargo feature. The `termexd` binary always
//! depends on this; mobile/desktop clients pull it in through the
//! Flutter bridge build.
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.7 for the
//! SDK design and §2.2 for the wire protocol.

pub mod artifact;
pub mod client;
pub mod protocol;

pub use artifact::{TaskArtifact, TaskArtifactSummary};
pub use client::{ClientError, DaemonClient};
pub use protocol::*;
