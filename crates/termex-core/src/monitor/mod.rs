//! Pure DTOs and shared types for the monitor subsystem.
//!
//! Remote collection over SSH — the batch command, the section splitter and
//! the `/proc` parsers — lives in [`collector`]. It is plain text parsing of
//! `/proc`, `df` and `ps` output, so it ships in OSS.
//!
//! Local-host sysinfo sampling and alert-rule evaluation remain in the
//! closed-source `termex-core-private::monitor`, linked only when the
//! consumer crate selects its `private` feature.
pub mod collector;
pub mod types;

pub use collector::{
    DerivedStats, MonitorSampler, Snapshot, build_batch_command, parse_snapshot, split_sections,
};
pub use types::*;
