use termex_core::ssh::channel::ChannelCommand;
use termex_flutter_bridge::api::ssh::{
    close_ssh_session, open_ssh_session, poll_ssh_events, resize_terminal, write_stdin,
};
use termex_flutter_bridge::frb_ssh_emitter::SshStreamEvent;
use termex_flutter_bridge::session_registry;
use tokio::sync::mpsc;

/// Inserts a cmd-only session entry for tests that exercise the write/resize
/// paths without establishing a real SSH connection.
fn register_session(id: &str) -> mpsc::UnboundedReceiver<ChannelCommand> {
    let (tx, rx) = mpsc::unbounded_channel();
    session_registry::insert_cmd_only(id.to_string(), tx);
    rx
}

#[tokio::test]
async fn open_ssh_session_rejects_unknown_server() {
    // No db_state is wired in unit tests, so loading the connect row must
    // produce an error rather than panic.
    let result = open_ssh_session("does-not-exist".into(), 80, 24).await;
    assert!(result.is_err(), "open_ssh_session should fail without a DB");
}

#[test]
fn write_stdin_unknown_session_returns_error() {
    let result = write_stdin("nonexistent-w".into(), b"hello".to_vec());
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("session not found"));
}

#[test]
fn resize_terminal_unknown_session_returns_error() {
    let result = resize_terminal("nonexistent-r".into(), 100, 40);
    assert!(result.is_err());
}

#[tokio::test]
async fn close_ssh_session_unknown_session_is_ok() {
    // close on unknown session must not panic or error
    let result = close_ssh_session("nonexistent-c".into()).await;
    assert!(result.is_ok());
}

#[tokio::test]
async fn write_stdin_sends_command_to_registered_session() {
    let mut rx = register_session("test-write");
    let payload = b"ls -la\n".to_vec();
    write_stdin("test-write".into(), payload.clone()).expect("write should succeed");
    let cmd = rx.try_recv().expect("command should be in channel");
    match cmd {
        ChannelCommand::Write(data) => assert_eq!(data, payload),
        _ => panic!("expected Write command"),
    }
    close_ssh_session("test-write".into()).await.unwrap();
}

#[tokio::test]
async fn resize_terminal_sends_command_to_registered_session() {
    let mut rx = register_session("test-resize");
    resize_terminal("test-resize".into(), 120, 40).expect("resize should succeed");
    let cmd = rx.try_recv().expect("command should be in channel");
    match cmd {
        ChannelCommand::Resize(cols, rows) => {
            assert_eq!(cols, 120);
            assert_eq!(rows, 40);
        }
        _ => panic!("expected Resize command"),
    }
    close_ssh_session("test-resize".into()).await.unwrap();
}

#[tokio::test]
async fn close_removes_session_from_registry() {
    register_session("test-close");
    assert!(session_registry::REGISTRY.contains_key("test-close"));
    close_ssh_session("test-close".into()).await.unwrap();
    assert!(!session_registry::REGISTRY.contains_key("test-close"));
}

#[tokio::test]
async fn close_is_idempotent() {
    register_session("test-idempotent");
    close_ssh_session("test-idempotent".into()).await.unwrap();
    // Second close on same session must not error
    let result = close_ssh_session("test-idempotent".into()).await;
    assert!(result.is_ok());
}

#[test]
fn poll_ssh_events_returns_empty_for_unknown_session() {
    let events: Vec<SshStreamEvent> = poll_ssh_events("never-opened".into());
    assert!(events.is_empty());
}
