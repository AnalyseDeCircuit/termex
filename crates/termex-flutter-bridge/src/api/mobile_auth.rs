/// Mobile authentication and lifecycle management stubs.
///
/// Biometric unlock is driven from the Dart side via `local_auth`; these
/// functions expose the Keychain-level operations and SSH keepalive control
/// that the Rust layer owns.
///
/// SSH keepalive suspend/resume are stubs until the SessionManager is wired
/// up in v0.62.0 (Mobile Foundation SSH layer).

// ─── Biometric availability ───────────────────────────────────────────────────

/// Returns true if the device has biometric hardware and enrolled credentials.
///
/// On non-mobile targets this always returns false. The definitive check is
/// performed in Dart via `local_auth.canCheckBiometrics` before calling
/// `biometric_unlock`; this function is a secondary signal for the Rust layer.
pub fn biometric_available() -> bool {
    #[cfg(any(target_os = "ios", target_os = "android"))]
    {
        // Delegate to platform-specific keychain module when available.
        false // placeholder — real impl in v0.58.0 biometric key entry
    }
    #[cfg(not(any(target_os = "ios", target_os = "android")))]
    {
        false
    }
}

/// Attempt to unlock the Keychain store using the platform biometric.
///
/// Returns `Ok(())` when the biometric challenge succeeds and the protected
/// Keychain entry is accessible.  Returns `Err(_)` on failure or cancellation.
///
/// The actual LAContext / BiometricPrompt challenge is orchestrated from Dart
/// (`local_auth`). This function is called *after* Dart confirms the
/// challenge was approved, to release the protected entry from Rust.
pub fn biometric_unlock() -> Result<(), String> {
    #[cfg(any(target_os = "ios", target_os = "android"))]
    {
        // v0.57.0 stub: assume unlock success when called post-Dart-challenge.
        Ok(())
    }
    #[cfg(not(any(target_os = "ios", target_os = "android")))]
    {
        Err("biometric unlock not supported on this platform".to_string())
    }
}

// ─── SSH keepalive lifecycle ──────────────────────────────────────────────────

/// Reduce keepalive frequency when the app enters the background.
///
/// Stub for v0.57.0 — real implementation in v0.62.0 once SessionManager
/// supports per-session keepalive interval adjustment.
pub fn suspend_all_keepalives() -> Result<(), String> {
    Ok(())
}

/// Restore full keepalive frequency when the app returns to the foreground.
pub fn resume_all_keepalives() -> Result<(), String> {
    Ok(())
}

/// Check whether an SSH session is still alive (channel responds to ping).
///
/// Returns `Ok(true)` if the session exists in the registry (channel is open),
/// `Ok(false)` if the session id is unknown (connection was dropped or never
/// established).
pub async fn check_session_alive(session_id: String) -> Result<bool, String> {
    Ok(crate::session_registry::REGISTRY.contains_key(&session_id))
}

/// Attempt to reconnect a dropped SSH session.
///
/// Stub for v0.57.0 — full reconnect logic (re-auth, channel restore) is
/// implemented in v0.62.0.  For now the function signals "reconnect scheduled"
/// by returning Ok(()), letting the Dart reconnect banner dismiss itself.
pub async fn reconnect_session(session_id: String) -> Result<(), String> {
    let _ = session_id;
    Ok(())
}
