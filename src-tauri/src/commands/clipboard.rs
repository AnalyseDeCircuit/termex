//! Clipboard access via native API (bypasses WKWebView paste confirmation dialog).

/// Reads text from the system clipboard.
/// Uses spawn_blocking to prevent blocking the main thread on macOS M1
/// where NSPasteboard access can hang if the pasteboard daemon is slow.
#[tauri::command]
pub async fn clipboard_read_text() -> Result<String, String> {
    tokio::task::spawn_blocking(|| {
        let mut clipboard = arboard::Clipboard::new().map_err(|e| e.to_string())?;
        clipboard.get_text().map_err(|e| e.to_string())
    })
    .await
    .map_err(|e| e.to_string())?
}

/// Writes text to the system clipboard.
///
/// `navigator.clipboard.writeText` is unavailable to code that is not running
/// in a user-gesture callback, which silently broke OSC 52 copies coming from
/// remote programs such as Zellij, tmux and vim (issue #19). The native path
/// has no such requirement.
#[tauri::command]
pub async fn clipboard_write_text(text: String) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let mut clipboard = arboard::Clipboard::new().map_err(|e| e.to_string())?;
        clipboard.set_text(text).map_err(|e| e.to_string())
    })
    .await
    .map_err(|e| e.to_string())?
}
