//! Tauri integration shim for the SFTP module now hosted in `termex-core`.
//!
//! This file exists only to provide the legacy `crate::sftp::...` import
//! paths used by `src-tauri/src/commands/sftp.rs` and `state.rs`. All
//! business logic lives in `termex_core::sftp`.

pub use termex_core::sftp::{SftpError, event_emitter, session};

pub mod tauri_emitter;
