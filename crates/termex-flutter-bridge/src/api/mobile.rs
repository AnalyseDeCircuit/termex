//! Mobile-only FRB API surface.
//!
//! These functions are generated into Dart via `flutter_rust_bridge`.
//! Run `./scripts/frb-codegen.sh` after any signature change.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

/// Supported haptic feedback styles for mobile.
pub enum HapticStyle {
    /// Light selection feedback (tap, selection change).
    Light,
    /// Medium impact (successful action, confirm).
    Medium,
    /// Heavy impact (destructive action).
    Heavy,
    /// Rigid impact (hard stop).
    Rigid,
    /// Soft impact (gentle nudge).
    Soft,
    /// Success notification.
    Success,
    /// Warning notification.
    Warning,
    /// Error notification.
    Error,
}

/// Returns the current platform identifier.
pub fn get_platform() -> String {
    #[cfg(target_os = "ios")]
    return "ios".to_string();
    #[cfg(target_os = "android")]
    return "android".to_string();
    #[cfg(target_os = "macos")]
    return "macos".to_string();
    #[cfg(target_os = "windows")]
    return "windows".to_string();
    #[cfg(target_os = "linux")]
    return "linux".to_string();
    #[allow(unreachable_code)]
    "unknown".to_string()
}

/// Returns true when running on iOS or Android.
pub fn is_mobile_platform() -> bool {
    cfg!(any(target_os = "ios", target_os = "android"))
}

/// Triggers a haptic feedback pulse on mobile.
/// On desktop this is a no-op.
pub fn haptic_feedback(style: HapticStyle) -> Result<(), String> {
    let _ = style;
    // Actual haptic is dispatched through the Flutter HapticFeedback channel
    // on the Dart side; this Rust entry point is a routing hook for
    // future native-side haptic enhancements (e.g. custom Core Haptics patterns).
    Ok(())
}

/// Returns the mobile Documents directory path for file storage.
pub fn mobile_documents_dir() -> Result<String, String> {
    #[cfg(any(target_os = "ios", target_os = "android"))]
    {
        dirs::document_dir()
            .map(|p| p.to_string_lossy().to_string())
            .ok_or_else(|| "documents directory unavailable".to_string())
    }
    #[cfg(not(any(target_os = "ios", target_os = "android")))]
    {
        Err("not a mobile platform".to_string())
    }
}

// ─── Staged delete (SwipeToDismiss undo buffer) ────────────────────────────

fn staged_map() -> &'static Mutex<HashMap<String, ()>> {
    static MAP: OnceLock<Mutex<HashMap<String, ()>>> = OnceLock::new();
    MAP.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Stage a server for deletion (called when the swipe is confirmed).
/// The actual DB delete does not happen until `commit_staged_delete`.
pub fn stage_delete_server(server_id: String) -> Result<(), String> {
    staged_map()
        .lock()
        .map_err(|e| e.to_string())?
        .insert(server_id, ());
    Ok(())
}

/// Confirm the staged deletion — performs the real DB delete.
/// If the server was already cancelled or was never staged, silently succeeds.
pub fn commit_staged_delete(server_id: String) -> Result<(), String> {
    let was_staged = staged_map()
        .lock()
        .map_err(|e| e.to_string())?
        .remove(&server_id)
        .is_some();
    if was_staged {
        // Delegate to the existing bridge-level server delete.
        crate::api::server::delete_server(server_id)?;
    }
    Ok(())
}

/// Cancel a staged deletion (undo tapped within Snackbar window).
pub fn cancel_staged_delete(server_id: String) -> Result<(), String> {
    staged_map()
        .lock()
        .map_err(|e| e.to_string())?
        .remove(&server_id);
    Ok(())
}
