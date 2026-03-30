use std::sync::Arc;

use tauri::{AppHandle, State};

use crate::sftp::session::FileEntry;
use crate::sftp::SftpError;
use crate::state::AppState;

/// Opens an SFTP session on an existing SSH connection.
/// The SSH session must already be connected via `ssh_connect`.
#[tauri::command]
pub async fn sftp_open(
    state: State<'_, AppState>,
    session_id: String,
) -> Result<(), String> {
    let sftp = {
        let sessions = state.sessions.read().await;
        let ssh = sessions
            .get(&session_id)
            .ok_or_else(|| SftpError::SshSessionNotFound(session_id.clone()).to_string())?;
        ssh.open_sftp()
            .await
            .map_err(|e| e.to_string())?
    };

    let mut sftp_sessions = state.sftp_sessions.write().await;
    sftp_sessions.insert(session_id, Arc::new(sftp));

    Ok(())
}

/// Closes an SFTP session.
#[tauri::command]
pub async fn sftp_close(
    state: State<'_, AppState>,
    session_id: String,
) -> Result<(), String> {
    let sftp = {
        let mut sessions = state.sftp_sessions.write().await;
        sessions
            .remove(&session_id)
            .ok_or_else(|| SftpError::SessionNotFound(session_id).to_string())?
    };
    // Try to unwrap the Arc; if there are pending transfers, the Arc will still be held by them
    // and we just drop it here. The session will be closed once all references are dropped.
    if let Ok(sftp_handle) = Arc::try_unwrap(sftp) {
        sftp_handle.close().await.map_err(|e| e.to_string())
    } else {
        // Arc still has references from pending transfers, just drop it
        Ok(())
    }
}

/// Lists directory contents at the given path.
#[tauri::command]
pub async fn sftp_list_dir(
    state: State<'_, AppState>,
    session_id: String,
    path: String,
) -> Result<Vec<FileEntry>, String> {
    let sessions = state.sftp_sessions.read().await;
    let sftp = sessions
        .get(&session_id)
        .ok_or_else(|| SftpError::SessionNotFound(session_id).to_string())?;
    sftp.list_dir(&path).await.map_err(|e| e.to_string())
}

/// Creates a directory.
#[tauri::command]
pub async fn sftp_mkdir(
    state: State<'_, AppState>,
    session_id: String,
    path: String,
) -> Result<(), String> {
    let sessions = state.sftp_sessions.read().await;
    let sftp = sessions
        .get(&session_id)
        .ok_or_else(|| SftpError::SessionNotFound(session_id).to_string())?;
    sftp.mkdir(&path).await.map_err(|e| e.to_string())
}

/// Deletes a file or directory.
#[tauri::command]
pub async fn sftp_delete(
    state: State<'_, AppState>,
    session_id: String,
    path: String,
    is_dir: bool,
) -> Result<(), String> {
    let sessions = state.sftp_sessions.read().await;
    let sftp = sessions
        .get(&session_id)
        .ok_or_else(|| SftpError::SessionNotFound(session_id).to_string())?;
    if is_dir {
        sftp.remove_dir(&path).await.map_err(|e| e.to_string())
    } else {
        sftp.remove_file(&path).await.map_err(|e| e.to_string())
    }
}

/// Renames a file or directory.
#[tauri::command]
pub async fn sftp_rename(
    state: State<'_, AppState>,
    session_id: String,
    old_path: String,
    new_path: String,
) -> Result<(), String> {
    let sessions = state.sftp_sessions.read().await;
    let sftp = sessions
        .get(&session_id)
        .ok_or_else(|| SftpError::SessionNotFound(session_id).to_string())?;
    sftp.rename(&old_path, &new_path)
        .await
        .map_err(|e| e.to_string())
}

/// Reads a small file into memory (for inline editing).
#[tauri::command]
pub async fn sftp_read_file(
    state: State<'_, AppState>,
    session_id: String,
    path: String,
) -> Result<Vec<u8>, String> {
    let sessions = state.sftp_sessions.read().await;
    let sftp = sessions
        .get(&session_id)
        .ok_or_else(|| SftpError::SessionNotFound(session_id).to_string())?;
    sftp.read_file(&path).await.map_err(|e| e.to_string())
}

/// Writes data to a remote file.
#[tauri::command]
pub async fn sftp_write_file(
    state: State<'_, AppState>,
    session_id: String,
    path: String,
    data: Vec<u8>,
) -> Result<(), String> {
    let sessions = state.sftp_sessions.read().await;
    let sftp = sessions
        .get(&session_id)
        .ok_or_else(|| SftpError::SessionNotFound(session_id).to_string())?;
    sftp.write_file(&path, &data)
        .await
        .map_err(|e| e.to_string())
}

/// Downloads a file from the remote server to a local path.
#[tauri::command]
pub async fn sftp_download(
    state: State<'_, AppState>,
    app: AppHandle,
    session_id: String,
    remote_path: String,
    local_path: String,
) -> Result<String, String> {
    let transfer_id = uuid::Uuid::new_v4().to_string();
    let sessions = state.sftp_sessions.read().await;
    let sftp = sessions
        .get(&session_id)
        .ok_or_else(|| SftpError::SessionNotFound(session_id.clone()).to_string())?;

    // Clone the SFTP handle for the background task
    let sftp_clone = sftp.clone();
    let transfer_id_clone = transfer_id.clone();
    let remote_path_clone = remote_path.clone();
    let local_path_clone = local_path.clone();

    // Return the transfer_id immediately, spawn the actual download in the background
    tokio::spawn(async move {
        let _ = sftp_clone.download(&remote_path_clone, &local_path_clone, &transfer_id_clone, &app).await;
    });

    Ok(transfer_id)
}

/// Uploads a local file to the remote server.
#[tauri::command]
pub async fn sftp_upload(
    state: State<'_, AppState>,
    app: AppHandle,
    session_id: String,
    local_path: String,
    remote_path: String,
) -> Result<String, String> {
    let transfer_id = uuid::Uuid::new_v4().to_string();
    let sessions = state.sftp_sessions.read().await;
    let sftp = sessions
        .get(&session_id)
        .ok_or_else(|| SftpError::SessionNotFound(session_id.clone()).to_string())?;

    // Clone the SFTP handle for the background task
    let sftp_clone = sftp.clone();
    let transfer_id_clone = transfer_id.clone();
    let local_path_clone = local_path.clone();
    let remote_path_clone = remote_path.clone();

    // Return the transfer_id immediately, spawn the actual upload in the background
    tokio::spawn(async move {
        let _ = sftp_clone.upload(&local_path_clone, &remote_path_clone, &transfer_id_clone, &app).await;
    });

    Ok(transfer_id)
}

/// Resolves the canonical path.
#[tauri::command]
pub async fn sftp_canonicalize(
    state: State<'_, AppState>,
    session_id: String,
    path: String,
) -> Result<String, String> {
    let sessions = state.sftp_sessions.read().await;
    let sftp = sessions
        .get(&session_id)
        .ok_or_else(|| SftpError::SessionNotFound(session_id).to_string())?;
    sftp.canonicalize(&path).await.map_err(|e| e.to_string())
}

// TODO: Implement chmod once russh-sftp provides setstat API
// Currently not supported in russh-sftp 2.1
// /// Changes file permissions (chmod).
// #[tauri::command]
// pub async fn sftp_chmod(
//     state: State<'_, AppState>,
//     session_id: String,
//     path: String,
//     mode: u32,
// ) -> Result<(), String> {
//     let sessions = state.sftp_sessions.read().await;
//     let sftp = sessions
//         .get(&session_id)
//         .ok_or_else(|| SftpError::SessionNotFound(session_id).to_string())?;
//     sftp.chmod(&path, mode).await.map_err(|e| e.to_string())
// }
