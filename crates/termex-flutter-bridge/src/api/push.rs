//! Push notification FRB API.
//!
//! Provides token registration / unregistration and local notification
//! dispatch. Firebase token delivery and display are handled on the Dart
//! side via `firebase_messaging`; these functions persist the token to the
//! single-entry keychain and trigger local OS notifications.
//!
//! Run `./scripts/frb-codegen.sh` after any signature change.

/// Registers an APNs / FCM push token.
///
/// The token is stored inside the single keychain entry (desktop: `keyring`
/// crate; iOS: Security.framework; Android: flutter_secure_storage).
/// This must not create a second keychain entry — the token is stored as
/// `termex:push:token` inside the existing JSON bundle.
pub async fn push_token_register(token: String, platform: String) -> Result<(), String> {
    // `store()` already flushes to the OS keychain when enabled (see
    // termex_core::keychain::store → flush()), so no extra flush call needed.
    let key = "termex:push:token";
    let meta_key = "termex:push:platform";
    termex_core::keychain::store(key, &token)
        .map_err(|e| e.to_string())?;
    termex_core::keychain::store(meta_key, &platform)
        .map_err(|e| e.to_string())?;
    Ok(())
}

/// Removes the stored push token (e.g. on sign-out or permission revocation).
pub async fn push_token_unregister() -> Result<(), String> {
    let _ = termex_core::keychain::delete("termex:push:token");
    let _ = termex_core::keychain::delete("termex:push:platform");
    Ok(())
}

/// Retrieves the stored push token, if any.
pub fn push_token_get() -> Option<String> {
    termex_core::keychain::get("termex:push:token").ok()
}

/// Dispatches a local notification (no remote APNs / FCM round-trip).
///
/// Used for in-app events: long SSH command completion, SFTP transfer done, etc.
pub async fn push_local_notification(
    title: String,
    body: String,
    deep_link: Option<String>,
) -> Result<(), String> {
    // Local notification display is handled by the Dart
    // `flutter_local_notifications` plugin; this Rust function is the
    // canonical entry point so callers in Rust core can trigger notifications
    // without a direct Dart dependency.
    let _ = (title, body, deep_link);
    // TODO(v0.70.0): implement via FRB callback once flutter_local_notifications
    // is added in the Monitor Dashboard iteration.
    Ok(())
}
