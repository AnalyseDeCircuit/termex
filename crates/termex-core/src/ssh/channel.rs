use russh::ChannelMsg;
use tokio::sync::mpsc;

use super::event_emitter::BoxedEmitter;

/// Message types for the background channel task.
pub enum ChannelCommand {
    Write(Vec<u8>),
    Resize(u32, u32),
    Close,
}

/// Handle for an active shell channel.
pub struct ChannelHandle {
    /// Send commands (write/resize/close) to the background channel task.
    pub cmd_tx: mpsc::UnboundedSender<ChannelCommand>,
    /// Handle to the background channel task.
    pub task_handle: tokio::task::JoinHandle<()>,
}

/// Spawns a background task that bridges an SSH channel with the frontend via `emitter`.
///
/// Reads data from the SSH server and forwards it through the emitter.
/// Receives user input and resize commands via the returned channel handle.
pub fn spawn_channel_task(
    mut channel: russh::Channel<russh::client::Msg>,
    emitter: BoxedEmitter,
    session_id: String,
) -> ChannelHandle {
    let (cmd_tx, mut cmd_rx) = mpsc::unbounded_channel::<ChannelCommand>();
    let sid = session_id.clone();

    let task_handle = tokio::spawn(async move {
        loop {
            tokio::select! {
                // SSH server → frontend
                msg = channel.wait() => {
                    match msg {
                        Some(ChannelMsg::Data { data }) => {
                            emitter.on_data_side_effect(&sid, &data).await;
                            emitter.emit_stdout(&sid, data.to_vec());
                        }
                        Some(ChannelMsg::ExitStatus { exit_status }) => {
                            emitter.emit_exit_status(&sid, exit_status);
                            break;
                        }
                        Some(ChannelMsg::Eof) | None => {
                            emitter.emit_disconnected(&sid);
                            break;
                        }
                        _ => {}
                    }
                }

                // Frontend → SSH server
                cmd = cmd_rx.recv() => {
                    match cmd {
                        Some(ChannelCommand::Write(data)) => {
                            if channel.data(&data[..]).await.is_err() {
                                break;
                            }
                        }
                        Some(ChannelCommand::Resize(cols, rows)) => {
                            let _ = channel
                                .window_change(cols, rows, 0, 0)
                                .await;
                        }
                        Some(ChannelCommand::Close) | None => break,
                    }
                }
            }
        }

        let _ = channel.eof().await;
        let _ = channel.close().await;
    });

    ChannelHandle {
        cmd_tx,
        task_handle,
    }
}
