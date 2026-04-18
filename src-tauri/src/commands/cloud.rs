use std::io::Read;
use std::sync::Mutex;
use std::collections::HashMap;

use portable_pty::{CommandBuilder, NativePtySystem, PtySize, PtySystem};
use tauri::{AppHandle, Emitter};

use crate::cloud::{detection, kube, ssm};
use crate::local_pty::PtyRegistry;
use crate::state::AppState;
use crate::storage::cloud_favorites::{CloudFavorite, CloudFavoriteInput};

// ── Detection ────────────────────────────────────────────────

#[tauri::command]
pub async fn cloud_detect_tools() -> Result<Vec<detection::ToolStatus>, String> {
    Ok(detection::detect_all().await)
}

#[tauri::command]
pub async fn cloud_kube_available() -> Result<bool, String> {
    Ok(detection::detect_kubectl().await.available)
}

#[tauri::command]
pub async fn cloud_ssm_available() -> Result<bool, String> {
    let aws = detection::detect_aws_cli().await;
    let ssm = detection::detect_ssm_plugin().await;
    Ok(aws.available && ssm.available)
}

// ── K8s ──────────────────────────────────────────────────────

#[tauri::command]
pub async fn cloud_kube_list_contexts() -> Result<Vec<kube::KubeContext>, String> {
    kube::list_contexts().await
}

#[tauri::command]
pub async fn cloud_kube_list_namespaces(context: String) -> Result<Vec<String>, String> {
    kube::list_namespaces(&context).await
}

#[tauri::command]
pub async fn cloud_kube_list_pods(
    context: String,
    namespace: String,
) -> Result<Vec<kube::PodInfo>, String> {
    kube::list_pods(&context, &namespace).await
}

#[tauri::command]
pub fn cloud_kube_exec(
    state: tauri::State<'_, PtyRegistry>,
    app: AppHandle,
    session_id: String,
    context: String,
    namespace: String,
    pod: String,
    container: Option<String>,
    shell: Option<String>,
    cols: u16,
    rows: u16,
) -> Result<(), String> {
    let pty_system = NativePtySystem::default();
    let pair = pty_system
        .openpty(PtySize {
            rows,
            cols,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|e| e.to_string())?;

    let mut cmd = CommandBuilder::new("kubectl");
    cmd.args(["--context", &context, "-n", &namespace, "exec", "-it", &pod]);
    if let Some(ref c) = container {
        cmd.args(["-c", c]);
    }
    cmd.args(["--", shell.as_deref().unwrap_or("/bin/sh")]);
    cmd.env("TERM", "xterm-256color");

    let child = pair.slave.spawn_command(cmd).map_err(|e| e.to_string())?;
    drop(pair.slave);

    let writer = pair.master.take_writer().map_err(|e| e.to_string())?;
    let mut reader = pair.master.try_clone_reader().map_err(|e| e.to_string())?;

    state.insert(session_id.clone(), pair.master, child, writer);

    let sid = session_id.clone();
    std::thread::spawn(move || {
        std::thread::sleep(std::time::Duration::from_millis(100));
        let mut buf = [0u8; 8192];
        loop {
            match reader.read(&mut buf) {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    let _ = app.emit(&format!("ssh://data/{sid}"), buf[..n].to_vec());
                }
            }
        }
        let _ = app.emit(
            &format!("ssh://status/{sid}"),
            serde_json::json!({ "status": "disconnected", "message": "kubectl exec ended" }),
        );
    });

    Ok(())
}

// ── AWS SSM ──────────────────────────────────────────────────

#[tauri::command]
pub async fn cloud_ssm_list_profiles() -> Result<Vec<String>, String> {
    ssm::list_profiles().await
}

#[tauri::command]
pub async fn cloud_ssm_list_instances(
    profile: Option<String>,
    region: Option<String>,
) -> Result<Vec<ssm::SsmInstance>, String> {
    ssm::list_instances(profile.as_deref(), region.as_deref()).await
}

#[tauri::command]
pub fn cloud_ssm_connect(
    state: tauri::State<'_, PtyRegistry>,
    app: AppHandle,
    session_id: String,
    instance_id: String,
    profile: Option<String>,
    region: Option<String>,
    cols: u16,
    rows: u16,
) -> Result<(), String> {
    let pty_system = NativePtySystem::default();
    let pair = pty_system
        .openpty(PtySize {
            rows,
            cols,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|e| e.to_string())?;

    let mut cmd = CommandBuilder::new("aws");
    cmd.args(["ssm", "start-session", "--target", &instance_id]);
    if let Some(ref p) = profile {
        cmd.args(["--profile", p]);
    }
    if let Some(ref r) = region {
        cmd.args(["--region", r]);
    }
    cmd.env("TERM", "xterm-256color");

    let child = pair.slave.spawn_command(cmd).map_err(|e| e.to_string())?;
    drop(pair.slave);

    let writer = pair.master.take_writer().map_err(|e| e.to_string())?;
    let mut reader = pair.master.try_clone_reader().map_err(|e| e.to_string())?;

    state.insert(session_id.clone(), pair.master, child, writer);

    let sid = session_id.clone();
    std::thread::spawn(move || {
        std::thread::sleep(std::time::Duration::from_millis(100));
        let mut buf = [0u8; 8192];
        loop {
            match reader.read(&mut buf) {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    let _ = app.emit(&format!("ssh://data/{sid}"), buf[..n].to_vec());
                }
            }
        }
        let _ = app.emit(
            &format!("ssh://status/{sid}"),
            serde_json::json!({ "status": "disconnected", "message": "SSM session ended" }),
        );
    });

    Ok(())
}

// ── K8s Logs ─────────────────────────────────────────────────

/// Registry for log stream tasks (stores abort handles).
pub struct LogRegistry {
    handles: Mutex<HashMap<String, tokio::task::AbortHandle>>,
}

impl LogRegistry {
    pub fn new() -> Self {
        Self {
            handles: Mutex::new(HashMap::new()),
        }
    }

    pub fn close_all(&self) {
        let mut handles = self.handles.lock().unwrap();
        for (_, handle) in handles.drain() {
            handle.abort();
        }
    }
}

#[tauri::command]
pub async fn cloud_kube_logs(
    state: tauri::State<'_, LogRegistry>,
    app: AppHandle,
    session_id: String,
    context: String,
    namespace: String,
    pod: String,
    container: Option<String>,
    tail_lines: Option<u32>,
    follow: bool,
) -> Result<(), String> {
    let mut cmd = tokio::process::Command::new("kubectl");
    cmd.args(["--context", &context, "-n", &namespace, "logs", &pod]);
    if let Some(ref c) = container {
        cmd.args(["-c", c]);
    }
    if let Some(n) = tail_lines {
        cmd.args(["--tail", &n.to_string()]);
    }
    if follow {
        cmd.arg("-f");
    }
    cmd.stdout(std::process::Stdio::piped());
    cmd.stderr(std::process::Stdio::piped());

    let mut child = cmd.spawn().map_err(|e| format!("kubectl logs failed: {}", e))?;
    let stdout = child
        .stdout
        .take()
        .ok_or("Failed to capture kubectl logs stdout")?;

    let sid = session_id.clone();
    let handle = tokio::spawn(async move {
        use tokio::io::AsyncReadExt;
        let mut reader = tokio::io::BufReader::new(stdout);
        let mut buf = vec![0u8; 8192];
        loop {
            match reader.read(&mut buf).await {
                Ok(0) | Err(_) => break,
                Ok(n) => {
                    let _ = app.emit(&format!("ssh://data/{sid}"), buf[..n].to_vec());
                }
            }
        }
        let _ = child.kill().await;
        let _ = app.emit(
            &format!("ssh://status/{sid}"),
            serde_json::json!({ "status": "disconnected", "message": "log stream ended" }),
        );
    });

    state
        .handles
        .lock()
        .unwrap()
        .insert(session_id.clone(), handle.abort_handle());

    Ok(())
}

#[tauri::command]
pub fn cloud_kube_logs_stop(
    state: tauri::State<'_, LogRegistry>,
    session_id: String,
) -> Result<(), String> {
    let mut handles = state.handles.lock().unwrap();
    if let Some(handle) = handles.remove(&session_id) {
        handle.abort();
    }
    Ok(())
}

// ── Cloud Favorites ──────────────────────────────────────────

/// Lists all cloud favorites.
#[tauri::command]
pub fn cloud_favorite_list(
    state: tauri::State<'_, AppState>,
) -> Result<Vec<CloudFavorite>, String> {
    state
        .db
        .with_conn(|conn| crate::storage::cloud_favorites::list(conn))
        .map_err(|e| e.to_string())
}

/// Creates a new cloud favorite (or returns existing one if same ref already exists).
#[tauri::command]
pub fn cloud_favorite_create(
    state: tauri::State<'_, AppState>,
    input: CloudFavoriteInput,
) -> Result<CloudFavorite, String> {
    // Idempotent: return existing if already saved
    let existing = state
        .db
        .with_conn(|conn| {
            crate::storage::cloud_favorites::find_by_ref(conn, &input.resource_type, &input.context_or_profile)
        })
        .map_err(|e| e.to_string())?;
    if let Some(fav) = existing {
        return Ok(fav);
    }
    state
        .db
        .with_conn(|conn| crate::storage::cloud_favorites::create(conn, &input))
        .map_err(|e| e.to_string())
}

/// Deletes a cloud favorite.
#[tauri::command]
pub fn cloud_favorite_delete(
    state: tauri::State<'_, AppState>,
    id: String,
) -> Result<(), String> {
    state
        .db
        .with_conn(|conn| crate::storage::cloud_favorites::delete(conn, &id))
        .map_err(|e| e.to_string())
}

/// Sets whether a cloud favorite is shared with the team.
#[tauri::command]
pub fn cloud_favorite_set_shared(
    state: tauri::State<'_, AppState>,
    id: String,
    shared: bool,
) -> Result<(), String> {
    state
        .db
        .with_conn(|conn| crate::storage::cloud_favorites::set_shared(conn, &id, shared))
        .map_err(|e| e.to_string())
}

/// Converts a team-received favorite to a locally-owned private favorite.
#[tauri::command]
pub fn cloud_favorite_make_local(
    state: tauri::State<'_, AppState>,
    id: String,
) -> Result<(), String> {
    state
        .db
        .with_conn(|conn| crate::storage::cloud_favorites::make_local(conn, &id))
        .map_err(|e| e.to_string())
}
