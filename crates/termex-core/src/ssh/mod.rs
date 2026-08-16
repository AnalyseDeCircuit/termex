pub mod auth;
pub mod channel;
pub mod config_parser;
pub mod event_emitter;
pub mod host_key;
pub mod proxy;
pub mod proxy_command;
pub mod reverse_forward;
pub mod session;
pub mod socks5;

/// Marker for "this key needs a passphrase I do not have".
///
/// Errors are flattened to strings at the Tauri command boundary, so the
/// frontend matches on these exact markers to decide whether to prompt the
/// user. Changing them requires updating `src/utils/sshErrors.ts` in step.
pub const KEY_PASSPHRASE_REQUIRED: &str = "ssh:key-passphrase-required";

/// Marker for "the passphrase supplied did not decrypt this key".
pub const KEY_PASSPHRASE_INCORRECT: &str = "ssh:key-passphrase-incorrect";

/// SSH error types.
#[derive(Debug, thiserror::Error)]
pub enum SshError {
    #[error("connection failed: {0}")]
    ConnectionFailed(String),

    #[error("authentication failed: {0}")]
    AuthFailed(String),

    #[error("channel error: {0}")]
    ChannelError(String),

    #[error("session not found: {0}")]
    SessionNotFound(String),

    #[error("session already disconnected")]
    AlreadyDisconnected,

    #[error("server not found: {0}")]
    ServerNotFound(String),

    #[error("russh error: {0}")]
    Russh(#[from] russh::Error),

    #[error("key error: {0}")]
    KeyError(#[from] russh_keys::Error),

    /// The private key is passphrase-protected and no passphrase was supplied.
    /// Distinct from [`SshError::AuthFailed`] so callers can prompt for one
    /// instead of requiring it to be stored with the server (issue #21).
    #[error("{}", KEY_PASSPHRASE_REQUIRED)]
    KeyPassphraseRequired,

    /// A passphrase was supplied but did not decrypt the private key.
    #[error("{}", KEY_PASSPHRASE_INCORRECT)]
    KeyPassphraseIncorrect,

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("crypto error: {0}")]
    Crypto(String),

    #[error("proxy connection failed: {0}")]
    ProxyFailed(String),
}
