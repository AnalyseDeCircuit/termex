//! Exit proxy for post-target routing.
//!
//! Starts a local SOCKS5 server that routes outbound traffic through
//! the post-target chain (SSH direct-tcpip or network proxy).
//! Combined with SSH remote port forwarding, this allows the target
//! to use the exit chain as its outbound proxy.

use std::collections::HashMap;
use std::sync::Arc;

use russh::ChannelMsg;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio::sync::RwLock;
use tokio_util::sync::CancellationToken;

use super::proxy::ProxyConfig;
use super::socks5;
use super::SshError;
use crate::state::{AppState, ProxyEntry};

/// Starts a local SOCKS5 proxy that routes traffic through an SSH session
/// stored in the proxy_sessions pool (looked up by server_id).
///
/// Returns `(local_port, task_handle)`.
pub async fn start_exit_socks5_via_pool(
    state: &AppState,
    exit_server_id: String,
    cancel: CancellationToken,
) -> Result<(u16, tokio::task::JoinHandle<()>), SshError> {
    let listener = TcpListener::bind("127.0.0.1:0")
        .await
        .map_err(SshError::Io)?;
    let local_port = listener.local_addr().map_err(SshError::Io)?.port();

    eprintln!(
        ">>> [EXIT_PROXY] SOCKS5 via SSH pool ({}) listening on 127.0.0.1:{}",
        exit_server_id, local_port
    );

    let proxy_sessions: Arc<RwLock<HashMap<String, ProxyEntry>>> = state.proxy_sessions.clone();
    let cancel_child = cancel.clone();
    let sid = exit_server_id.clone();

    let task = tokio::spawn(async move {
        loop {
            tokio::select! {
                result = listener.accept() => {
                    match result {
                        Ok((stream, _)) => {
                            let ps = proxy_sessions.clone();
                            let id = sid.clone();
                            tokio::spawn(async move {
                                handle_socks5_pool(stream, ps, id).await;
                            });
                        }
                        Err(_) => break,
                    }
                }
                _ = cancel_child.cancelled() => break,
            }
        }
    });

    Ok((local_port, task))
}

/// Handles a single SOCKS5 connection by routing through an SSH session from the pool.
async fn handle_socks5_pool(
    mut stream: tokio::net::TcpStream,
    proxy_sessions: Arc<RwLock<HashMap<String, ProxyEntry>>>,
    exit_server_id: String,
) {
    let (target_host, target_port) = match socks5::socks5_handshake(&mut stream).await {
        Ok(addr) => addr,
        Err(_) => return,
    };

    let sessions = proxy_sessions.read().await;
    let Some(entry) = sessions.get(&exit_server_id) else {
        let _ = socks5::socks5_reply_failure(&mut stream, socks5::REPLY_GENERAL_FAILURE).await;
        return;
    };

    let channel = match entry
        .session
        .handle()
        .channel_open_direct_tcpip(&target_host, target_port as u32, "127.0.0.1", 0)
        .await
    {
        Ok(ch) => ch,
        Err(_) => {
            let _ = socks5::socks5_reply_failure(&mut stream, socks5::REPLY_HOST_UNREACHABLE).await;
            return;
        }
    };
    drop(sessions);

    if socks5::socks5_reply_success(&mut stream).await.is_err() {
        return;
    }

    bridge_tcp_channel(stream, channel).await;
}

/// Starts a local SOCKS5 proxy that routes traffic through a network proxy
/// reachable via the target session's direct-tcpip channel.
/// Uses AppHandle to look up the target session by session_id (same pattern as port forwarding).
///
/// Returns `(local_port, task_handle)`.
pub async fn start_exit_socks5_via_proxy(
    app: tauri::AppHandle,
    target_session_id: String,
    proxy_config: ProxyConfig,
    cancel: CancellationToken,
) -> Result<(u16, tokio::task::JoinHandle<()>), SshError> {
    let listener = TcpListener::bind("127.0.0.1:0")
        .await
        .map_err(SshError::Io)?;
    let local_port = listener.local_addr().map_err(SshError::Io)?.port();

    eprintln!(
        ">>> [EXIT_PROXY] SOCKS5 via proxy {}:{} listening on 127.0.0.1:{}",
        proxy_config.host, proxy_config.port, local_port
    );

    let cancel_child = cancel.clone();
    let task = tokio::spawn(async move {
        loop {
            tokio::select! {
                result = listener.accept() => {
                    match result {
                        Ok((stream, _)) => {
                            let app2 = app.clone();
                            let sid = target_session_id.clone();
                            let config = proxy_config.clone();
                            tokio::spawn(async move {
                                handle_socks5_proxy_via_target(stream, app2, sid, config).await;
                            });
                        }
                        Err(_) => break,
                    }
                }
                _ = cancel_child.cancelled() => break,
            }
        }
    });

    Ok((local_port, task))
}

/// Handles a single SOCKS5 connection by connecting to the proxy directly
/// from Termex's local machine (not through the Target), then bridging.
async fn handle_socks5_proxy_via_target(
    mut stream: tokio::net::TcpStream,
    _app: tauri::AppHandle,
    _target_session_id: String,
    proxy_config: ProxyConfig,
) {
    use super::proxy;

    // SOCKS5 handshake with the local client (curl on Target → remote port forward → here)
    let (target_host, target_port) = match socks5::socks5_handshake(&mut stream).await {
        Ok(addr) => addr,
        Err(_) => return,
    };

    // Connect to the proxy directly from Termex's local machine
    // This handles TLS, authentication, and SOCKS5/HTTP CONNECT handshake
    let tunneled = match proxy::connect_via_proxy(
        &proxy_config,
        &target_host,
        target_port,
    )
    .await
    {
        Ok(s) => s,
        Err(e) => {
            eprintln!(">>> [EXIT_PROXY] Failed to connect via proxy: {}", e);
            let _ = socks5::socks5_reply_failure(&mut stream, socks5::REPLY_HOST_UNREACHABLE).await;
            return;
        }
    };

    // Send SOCKS5 success reply
    if socks5::socks5_reply_success(&mut stream).await.is_err() {
        return;
    }

    // Bridge: local client ↔ proxy tunnel ↔ internet
    bridge_tcp_async(stream, tunneled).await;
}

/// Bridges a local TCP stream with an SSH channel bidirectionally.
async fn bridge_tcp_channel(
    local_stream: tokio::net::TcpStream,
    mut channel: russh::Channel<russh::client::Msg>,
) {
    let (mut local_rd, mut local_wr) = local_stream.into_split();
    let mut buf = vec![0u8; 32768];

    loop {
        tokio::select! {
            result = local_rd.read(&mut buf) => {
                match result {
                    Ok(0) | Err(_) => break,
                    Ok(n) => {
                        if channel.data(&buf[..n]).await.is_err() {
                            break;
                        }
                    }
                }
            }
            msg = channel.wait() => {
                match msg {
                    Some(ChannelMsg::Data { data }) => {
                        if local_wr.write_all(&data).await.is_err() {
                            break;
                        }
                    }
                    Some(ChannelMsg::Eof) | None => break,
                    _ => {}
                }
            }
        }
    }

    let _ = channel.close().await;
}

/// Bridges a local TCP stream with a generic async stream bidirectionally.
async fn bridge_tcp_async(
    local_stream: tokio::net::TcpStream,
    mut remote: Box<dyn super::proxy::AsyncStream>,
) {
    let (mut local_rd, mut local_wr) = local_stream.into_split();
    let mut local_buf = vec![0u8; 32768];
    let mut remote_buf = vec![0u8; 32768];

    loop {
        tokio::select! {
            result = local_rd.read(&mut local_buf) => {
                match result {
                    Ok(0) | Err(_) => break,
                    Ok(n) => {
                        if remote.write_all(&local_buf[..n]).await.is_err() {
                            break;
                        }
                    }
                }
            }
            result = remote.read(&mut remote_buf) => {
                match result {
                    Ok(0) | Err(_) => break,
                    Ok(n) => {
                        if local_wr.write_all(&remote_buf[..n]).await.is_err() {
                            break;
                        }
                    }
                }
            }
        }
    }
}
