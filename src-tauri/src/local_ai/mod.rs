//! Tauri integration shim for the local-AI module now hosted in
//! `termex-core::local_ai`.
//!
//! Business logic (process lifecycle, binary management, downloads, pid
//! file handling, port probing) lives in `termex-core`. The Tauri layer
//! retains only the AppState-coupled `health_check` restart loop, which
//! needs access to the live `AppState::llama_server` handle.

pub use termex_core::local_ai::*;
pub use termex_core::local_ai::{binary_manager, downloader, port_check, storage};

pub mod health_check;
