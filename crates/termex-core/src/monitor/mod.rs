//! Pure DTOs and shared types for the monitor subsystem.
//!
//! The async collectors (local sysinfo sampling, remote `top`/`ps` parsing,
//! alert rule evaluation, batch command builders) live in the closed-source
//! `termex-core-private::monitor` and are only linked when the consumer
//! crate selects its `private` feature.
pub mod types;

pub use types::*;
