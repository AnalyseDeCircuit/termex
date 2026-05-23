//! Public DTOs for the team-collaboration subsystem.
//!
//! The crypto / git / permission / sync implementations live in the
//! closed-source `termex-core-private::team` and are only linked when the
//! consumer crate selects its `private` feature.
pub mod types;

pub use types::*;
