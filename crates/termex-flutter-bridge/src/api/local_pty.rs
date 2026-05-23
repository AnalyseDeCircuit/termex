//! Local PTY session management.
//!
//! Opens the user's default shell in a native pseudo-terminal. Events
//! (stdout, exit) are pushed into the shared `frb_ssh_emitter` queue so
//! Dart's existing `poll_ssh_events` + `write_stdin` + `resize_terminal`
//! pipeline works unchanged for local sessions.

use once_cell::sync::Lazy;
use portable_pty::{CommandBuilder, NativePtySystem, PtySize, PtySystem};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::sync::Mutex;
use std::thread;
use uuid::Uuid;

use crate::frb_ssh_emitter;

struct PtySession {
    master: Box<dyn portable_pty::MasterPty + Send>,
    writer: Box<dyn Write + Send>,
    child: Box<dyn portable_pty::Child + Send + Sync>,
}

static LOCAL_SESSIONS: Lazy<Mutex<HashMap<String, PtySession>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

/// Opens a local shell and returns a `sessionId` that is usable with
/// `poll_ssh_events`, `write_stdin`, `resize_terminal`, and
/// `close_ssh_session` — no further local-specific API calls needed.
pub fn open_local_pty(cols: u32, rows: u32) -> Result<String, String> {
    let session_id = Uuid::new_v4().to_string();

    let pty_system = NativePtySystem::default();
    let pair = pty_system
        .openpty(PtySize {
            rows: rows as u16,
            cols: cols as u16,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|e| e.to_string())?;

    let mut cmd = CommandBuilder::new_default_prog();
    cmd.env("TERM", "xterm-256color");

    let child = pair.slave.spawn_command(cmd).map_err(|e| e.to_string())?;
    drop(pair.slave);

    let writer = pair.master.take_writer().map_err(|e| e.to_string())?;
    let mut reader = pair.master.try_clone_reader().map_err(|e| e.to_string())?;

    frb_ssh_emitter::register_session(session_id.clone());

    let sid = session_id.clone();
    thread::spawn(move || {
        let mut buf = [0u8; 4096];
        loop {
            match reader.read(&mut buf) {
                Ok(0) | Err(_) => {
                    frb_ssh_emitter::push_disconnected(&sid);
                    if let Ok(mut m) = LOCAL_SESSIONS.lock() {
                        m.remove(&*sid);
                    }
                    break;
                }
                Ok(n) => {
                    frb_ssh_emitter::push_stdout(&sid, buf[..n].to_vec());
                }
            }
        }
    });

    LOCAL_SESSIONS.lock().unwrap().insert(
        session_id.clone(),
        PtySession {
            master: pair.master,
            writer,
            child,
        },
    );

    Ok(session_id)
}

/// Returns `true` when `session_id` identifies a local PTY session.
/// Used by `write_stdin`, `resize_terminal`, and `close_ssh_session`
/// to route local sessions without adding new Dart API surface.
pub fn is_local_session(session_id: &str) -> bool {
    LOCAL_SESSIONS
        .lock()
        .map(|m| m.contains_key(session_id))
        .unwrap_or(false)
}

/// Writes bytes to the local PTY stdin.
pub fn write_stdin(session_id: &str, data: Vec<u8>) -> Result<(), String> {
    let mut sessions = LOCAL_SESSIONS.lock().map_err(|e| e.to_string())?;
    let session = sessions
        .get_mut(session_id)
        .ok_or_else(|| "Local PTY session not found".to_string())?;
    session.writer.write_all(&data).map_err(|e| e.to_string())?;
    session.writer.flush().map_err(|e| e.to_string())
}

/// Resizes the local PTY.
pub fn resize(session_id: &str, cols: u32, rows: u32) -> Result<(), String> {
    let mut sessions = LOCAL_SESSIONS.lock().map_err(|e| e.to_string())?;
    let session = sessions
        .get_mut(session_id)
        .ok_or_else(|| "Local PTY session not found".to_string())?;
    session
        .master
        .resize(PtySize {
            rows: rows as u16,
            cols: cols as u16,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|e| e.to_string())
}

/// Closes a local PTY session and unregisters its event queue.
pub fn close(session_id: &str) {
    let mut s = LOCAL_SESSIONS
        .lock()
        .ok()
        .and_then(|mut m| m.remove(session_id));
    if let Some(ref mut session) = s {
        let _ = session.child.kill();
    }
    frb_ssh_emitter::unregister_session(session_id);
}
