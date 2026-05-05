// Re-export pure SSH core from termex-core
pub use termex_core::ssh::auth;
pub use termex_core::ssh::channel;
pub use termex_core::ssh::config_parser;
pub use termex_core::ssh::event_emitter;
pub use termex_core::ssh::host_key;
pub use termex_core::ssh::proxy;
pub use termex_core::ssh::proxy_command;
pub use termex_core::ssh::reverse_forward;
pub use termex_core::ssh::session;
pub use termex_core::ssh::socks5;
pub use termex_core::ssh::SshError;

// Tauri-specific modules
pub mod chain_connect;
pub mod exit_proxy;
pub mod forward;
pub mod tauri_emitter;
