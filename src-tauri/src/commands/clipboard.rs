//! Clipboard access via native API (bypasses WKWebView paste confirmation dialog).

/// Reads text from the system clipboard.
#[tauri::command]
pub fn clipboard_read_text() -> Result<String, String> {
    let mut clipboard = arboard::Clipboard::new().map_err(|e| e.to_string())?;
    clipboard.get_text().map_err(|e| e.to_string())
}
