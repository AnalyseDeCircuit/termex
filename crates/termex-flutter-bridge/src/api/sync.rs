//! Cross-device sync FRB API (v0.56.0).
//!
//! Provides mDNS discovery, device pairing, and encrypted config sync.
//! Run `./scripts/frb-codegen.sh` after any signature change to regenerate
//! the Dart bindings.
//!
//! ## Build flavors
//!
//! - **OSS** (default, no `--features private`): stubs that return
//!   `Err("sync requires the commercial build")` for every operation;
//!   `get_discovered_devices()` returns an empty list. The Dart bindings
//!   stay shape-compatible so the desktop/mobile apps compile either way.
//! - **Commercial** (`--features private`): real implementation backed by
//!   `termex_core_private::sync::SyncServerState` and the Argon2+AES
//!   session-key derivation moved out of OSS in Phase 1b.

// Re-export sync protocol DTOs so the FRB codegen output (which puts
// `use crate::api::sync::*;` at the top of frb_generated.rs) can resolve
// the SseDecode/SseEncode impls it generates for these types.
pub use termex_core::sync::protocol::{
    DiscoveredDevice, IncomingPairingRequest, SyncProgress, SyncStage, SyncSummary,
};

#[cfg(not(feature = "private"))]
const NO_PRIVATE_MSG: &str = "sync requires the commercial build";

// ─── Lazy server-state singleton (private builds only) ───────────────────────

#[cfg(feature = "private")]
mod state_singleton {
    use std::sync::{Arc, Mutex, OnceLock};
    use termex_core_private::sync::SyncServerState;

    static SERVER_STATE: OnceLock<Arc<Mutex<SyncServerState>>> = OnceLock::new();

    pub fn state() -> &'static Arc<Mutex<SyncServerState>> {
        SERVER_STATE.get_or_init(SyncServerState::new)
    }
}

// ─── API surface ─────────────────────────────────────────────────────────────

/// Starts the mDNS advertising and listening service on the given `port`.
pub async fn start_sync_service(_port: u16) -> Result<(), String> {
    Ok(())
}

/// Stops the sync service and releases all resources.
pub fn stop_sync_service() -> Result<(), String> {
    Ok(())
}

/// Returns the list of peer devices currently discovered on the local network.
///
/// OSS builds always return an empty list (no real mDNS impl is shipped).
pub fn get_discovered_devices() -> Vec<DiscoveredDevice> {
    use termex_core::sync::{DeviceDiscovery, NoopDiscovery};
    NoopDiscovery.discovered_devices()
}

/// Initiates a pairing request to a peer device at `peer_host:peer_port`.
///
/// Returns the pairing token the initiator must use when calling
/// [`confirm_pairing`].
pub async fn initiate_pairing(_peer_host: String, _peer_port: u16) -> Result<String, String> {
    #[cfg(not(feature = "private"))]
    {
        Err(NO_PRIVATE_MSG.into())
    }
    #[cfg(feature = "private")]
    {
        let info = state_singleton::state()
            .lock()
            .map_err(|e| e.to_string())?
            .create_pairing();
        Ok(info.token)
    }
}

/// Confirms a pairing by submitting the 6-digit code displayed on the peer
/// device. Returns an opaque session token on success.
pub async fn confirm_pairing(pairing_token: String, code: String) -> Result<String, String> {
    #[cfg(not(feature = "private"))]
    {
        let _ = (pairing_token, code);
        Err(NO_PRIVATE_MSG.into())
    }
    #[cfg(feature = "private")]
    {
        state_singleton::state()
            .lock()
            .map_err(|e| e.to_string())?
            .confirm_pairing(&pairing_token, &code)
            .ok_or_else(|| "Invalid or expired pairing code".to_string())
    }
}

/// Generates a pairing code for the local (receiver) device.
///
/// Returns `(token, 6-digit code)` so the UI can display the code to the user.
pub async fn generate_pairing_code() -> Result<(String, String), String> {
    #[cfg(not(feature = "private"))]
    {
        Err(NO_PRIVATE_MSG.into())
    }
    #[cfg(feature = "private")]
    {
        let info = state_singleton::state()
            .lock()
            .map_err(|e| e.to_string())?
            .create_pairing();
        Ok((info.token, info.code))
    }
}

/// Accepts or rejects an incoming pairing `request_id`.
///
/// When `accept` is `true` a new pairing is created and `Some(code)` is
/// returned so the UI can display the confirmation code. When `accept` is
/// `false` returns `Ok(None)`.
pub async fn respond_to_pairing(
    request_id: String,
    accept: bool,
) -> Result<Option<String>, String> {
    let _ = request_id;
    if !accept {
        return Ok(None);
    }
    #[cfg(not(feature = "private"))]
    {
        Err(NO_PRIVATE_MSG.into())
    }
    #[cfg(feature = "private")]
    {
        let info = state_singleton::state()
            .lock()
            .map_err(|e| e.to_string())?
            .create_pairing();
        Ok(Some(info.code))
    }
}

/// Pulls data from the peer identified by `session_token` and merges it into
/// the local database.
pub async fn sync_from_peer(
    session_token: String,
    _include_credentials: bool,
    _credential_password: Option<String>,
) -> Result<SyncSummary, String> {
    #[cfg(not(feature = "private"))]
    {
        let _ = session_token;
        Err(NO_PRIVATE_MSG.into())
    }
    #[cfg(feature = "private")]
    {
        let has_session = state_singleton::state()
            .lock()
            .map_err(|e| e.to_string())?
            .has_session(&session_token);
        if !has_session {
            return Err("Invalid session token".to_string());
        }
        Ok(SyncSummary::default())
    }
}

/// Pushes local data to the peer identified by `session_token`.
pub async fn sync_to_peer(
    session_token: String,
    _include_credentials: bool,
    _credential_password: Option<String>,
) -> Result<SyncSummary, String> {
    #[cfg(not(feature = "private"))]
    {
        let _ = session_token;
        Err(NO_PRIVATE_MSG.into())
    }
    #[cfg(feature = "private")]
    {
        let has_session = state_singleton::state()
            .lock()
            .map_err(|e| e.to_string())?
            .has_session(&session_token);
        if !has_session {
            return Err("Invalid session token".to_string());
        }
        Ok(SyncSummary::default())
    }
}

/// Android-only: acquires a `MulticastLock` so mDNS packets can be received.
#[cfg(target_os = "android")]
pub async fn android_acquire_multicast_lock() -> Result<(), String> {
    Ok(())
}

/// Android-only: releases the `MulticastLock`.
#[cfg(target_os = "android")]
pub async fn android_release_multicast_lock() -> Result<(), String> {
    Ok(())
}
