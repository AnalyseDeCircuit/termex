//! Bearer-token authentication for the WebSocket upgrade handshake.
//!
//! On first start, termexd generates a 32-byte random token (ring's
//! `SecureRandom`), hex-encodes it, and writes it to
//! `~/.termex/daemon.token` with mode 0600. The token is also echoed
//! to stdout so the user can copy it over an SSH session into the
//! Termex client.
//!
//! See `docs/iterations/v0.71.0-core-termexd-daemon.md` §2.2.1.

use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;

use ring::rand::{SecureRandom, SystemRandom};

use crate::error::DaemonError;

const TOKEN_BYTES: usize = 32;
const TOKEN_FILE_NAME: &str = "daemon.token";

/// Loads the existing token from `~/.termex/daemon.token`, or generates
/// and persists a fresh one if none exists.
///
/// The returned token is the hex string clients pass in the
/// `Authorization: Bearer <token>` header.
pub fn load_or_create_token(termex_home: &PathBuf) -> Result<String, DaemonError> {
    let path = termex_home.join(TOKEN_FILE_NAME);
    if let Ok(existing) = fs::read_to_string(&path) {
        let trimmed = existing.trim();
        if !trimmed.is_empty() {
            return Ok(trimmed.to_string());
        }
    }

    let rng = SystemRandom::new();
    let mut bytes = [0u8; TOKEN_BYTES];
    rng.fill(&mut bytes)
        .map_err(|_| DaemonError::Internal("rng fill failed".into()))?;
    let token = hex::encode(bytes);

    fs::create_dir_all(termex_home).map_err(DaemonError::PtyIo)?;
    fs::write(&path, &token).map_err(DaemonError::PtyIo)?;

    // chmod 0600
    let perms = fs::Permissions::from_mode(0o600);
    fs::set_permissions(&path, perms).map_err(DaemonError::PtyIo)?;

    Ok(token)
}

/// Constant-time comparison to mitigate timing attacks on token
/// verification. (Bearer tokens are server-generated and the attack
/// surface is small, but it costs nothing to do this right.)
pub fn verify_token(expected: &str, presented: &str) -> bool {
    if expected.len() != presented.len() {
        return false;
    }
    let mut diff: u8 = 0;
    for (a, b) in expected.bytes().zip(presented.bytes()) {
        diff |= a ^ b;
    }
    diff == 0
}
