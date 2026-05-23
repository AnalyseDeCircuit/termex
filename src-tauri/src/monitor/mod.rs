pub mod collector;

// DTOs (always available via OSS termex-core).
pub use termex_core::monitor::types;

// Parser implementations live in `termex-core-private` — only re-exported
// when the `private` Cargo feature is selected. OSS builds reference
// `parser` only through code paths that are themselves cfg-gated.
#[cfg(feature = "private")]
pub use termex_core_private::monitor::parser;

pub use collector::{CollectorCommand, CollectorState, MetricsHistory};
pub use types::*;
