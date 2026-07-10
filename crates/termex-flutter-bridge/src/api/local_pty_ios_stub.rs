//! Mobile (iOS / Android) stub for local PTY session management.
//!
//! Mobile sandboxes forbid `fork`/`exec`, terminal ioctls and pseudo-terminal
//! devices, so a real local shell session cannot exist on these platforms.
//! This stub mirrors the desktop module's public signatures verbatim so the
//! FRB-generated bindings and the `ssh.rs` routing layer compile and link
//! on mobile targets without code changes. All entry points return a
//! "not supported" error or report no local session.

/// Returns an error on mobile — local shells are unavailable in the sandbox.
pub fn open_local_pty(_cols: u32, _rows: u32) -> Result<String, String> {
    Err("local PTY is not available on mobile".to_string())
}

/// Always `false` on mobile: no session can have been opened.
pub fn is_local_session(_session_id: &str) -> bool {
    false
}

/// Returns an error on mobile — there is never a local session to write to.
pub fn write_stdin(_session_id: &str, _data: Vec<u8>) -> Result<(), String> {
    Err("local PTY is not available on mobile".to_string())
}

/// Returns an error on mobile — there is never a local session to resize.
pub fn resize(_session_id: &str, _cols: u32, _rows: u32) -> Result<(), String> {
    Err("local PTY is not available on mobile".to_string())
}

/// No-op on mobile — there is never a local session to close.
pub fn close(_session_id: &str) {}
