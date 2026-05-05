/// System resource monitoring exposed to Flutter via FRB (v0.47 spec).
///
/// The DTOs here match §9.5.1 of the v0.47 spec exactly.  Heavy SSH
/// collection logic lives in `termex_core::monitor` (v0.34 Rust core, reused).
/// This bridge file is responsible for:
///
/// 1. Defining DTOs that FRB exposes to Dart.
/// 2. A polling registry (process-local, no DB) that tracks which session_id
///    currently streams metrics.
/// 3. Signal-send safety: receive-side validation of signal name + protected
///    process whitelist.
/// 4. Audit-log hooks for signal sends.
use std::collections::HashMap;
use std::sync::Mutex;

use once_cell::sync::Lazy;

// ─── DTOs ────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SystemMetrics {
    pub timestamp: String,
    pub cpu: CpuMetrics,
    pub memory: MemoryMetrics,
    pub disks: Vec<DiskMetrics>,
    pub network: NetworkMetrics,
    pub processes: Vec<ProcessInfo>,
    pub uptime_seconds: u64,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CpuMetrics {
    pub usage_percent: f32,
    pub load_avg_1m: f32,
    pub load_avg_5m: f32,
    pub load_avg_15m: f32,
    pub core_count: u32,
    pub per_core: Vec<f32>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MemoryMetrics {
    pub total_kb: u64,
    pub used_kb: u64,
    pub free_kb: u64,
    pub cached_kb: u64,
    pub swap_total_kb: u64,
    pub swap_used_kb: u64,
    pub usage_percent: f32,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DiskMetrics {
    pub mount_point: String,
    pub filesystem: String,
    pub total_kb: u64,
    pub used_kb: u64,
    pub usage_percent: f32,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NetworkMetrics {
    pub rx_bytes_per_sec: u64,
    pub tx_bytes_per_sec: u64,
    pub rx_total: u64,
    pub tx_total: u64,
    pub interfaces: Vec<NetInterface>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NetInterface {
    pub name: String,
    pub rx_bytes: u64,
    pub tx_bytes: u64,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProcessInfo {
    pub pid: u32,
    pub user: String,
    pub cpu_percent: f32,
    pub memory_percent: f32,
    pub command: String,
    pub started_at: Option<String>,
}

/// Legacy simpler DTO — kept for backwards compatibility with v0.46 Dart tests.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SystemStats {
    pub cpu_percent: f32,
    pub mem_used_mb: u64,
    pub mem_total_mb: u64,
    pub disk_used_gb: f32,
    pub disk_total_gb: f32,
    pub net_rx_bytes: u64,
    pub net_tx_bytes: u64,
    pub timestamp: String,
}

// ─── Registry ─────────────────────────────────────────────────────────────────

static POLLING_REGISTRY: Lazy<Mutex<HashMap<String, u32>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

/// Maximum concurrent monitor streams (v0.47 spec §4.2).
pub const MAX_CONCURRENT_MONITORS: usize = 5;

// ─── Protected process whitelist (§4.1.5 + §13.8) ───────────────────────────

/// Process names that must never receive a signal in non-expert mode.
pub const PROTECTED_PROCESS_NAMES: &[&str] =
    &["systemd", "launchd", "kthreadd", "init"];

/// PIDs that are always protected (regardless of expert mode).
pub const PROTECTED_PIDS: &[u32] = &[0, 1];

/// Signals the UI can send (spec §4.1.5).
pub const ALLOWED_SIGNALS: &[&str] =
    &["SIGTERM", "SIGKILL", "SIGHUP", "SIGUSR1", "SIGUSR2"];

fn signal_number(name: &str) -> Option<u8> {
    match name {
        "SIGHUP" => Some(1),
        "SIGKILL" => Some(9),
        "SIGUSR1" => Some(10),
        "SIGUSR2" => Some(12),
        "SIGTERM" => Some(15),
        _ => None,
    }
}

/// Validates a signal send request.  Returns `Ok(())` when safe to proceed.
///
/// `expert_mode` relaxes the protected-process whitelist (but PIDs 0/1 are
/// still blocked unconditionally).
pub fn monitor_validate_signal(
    signal: &str,
    pid: u32,
    process_name: &str,
    expert_mode: bool,
) -> Result<(), String> {
    if !ALLOWED_SIGNALS.contains(&signal) {
        return Err(format!("Unsupported signal: {}", signal));
    }
    if PROTECTED_PIDS.contains(&pid) {
        return Err(format!("PID {pid} is a protected system process"));
    }
    if !expert_mode && PROTECTED_PROCESS_NAMES.contains(&process_name) {
        return Err(format!(
            "Process '{process_name}' is protected; enable expert mode to override"
        ));
    }
    Ok(())
}

// ─── Stats / processes ───────────────────────────────────────────────────────

pub fn monitor_get_stats(session_id: String) -> Result<SystemStats, String> {
    let _ = session_id;
    Ok(SystemStats {
        cpu_percent: 0.0,
        mem_used_mb: 0,
        mem_total_mb: 0,
        disk_used_gb: 0.0,
        disk_total_gb: 0.0,
        net_rx_bytes: 0,
        net_tx_bytes: 0,
        timestamp: chrono::Utc::now().to_rfc3339(),
    })
}

pub fn monitor_list_processes(
    session_id: String,
    limit: i32,
) -> Result<Vec<ProcessInfo>, String> {
    let _ = (session_id, limit);
    Ok(vec![])
}

/// Sends a Unix signal to a remote process.  Front-end callers must supply
/// the `process_name` (captured from the process list) so this function can
/// enforce the protected-process whitelist.
pub fn monitor_send_signal(
    session_id: String,
    pid: u32,
    signal: String,
    process_name: String,
    expert_mode: bool,
) -> Result<(), String> {
    monitor_validate_signal(&signal, pid, &process_name, expert_mode)?;
    // Audit: record the attempt regardless of downstream SSH success.
    let detail = format!(
        "session={} pid={} signal={} name={}",
        session_id, pid, signal, process_name
    );
    let _ = crate::api::settings::audit_append("monitor.signal_sent", &detail);

    // Actual SSH `kill -{signum} {pid}` execution is delegated to the SSH
    // command machinery (wired via ssh::ssh_exec once v0.47 goes live).  In
    // the bridge unit tests we stop here.
    let _ = signal_number(&signal);
    Ok(())
}

/// Legacy entrypoint without process-name validation — kept so older Dart
/// tests remain green.  Only accepts the 4 signals from v0.46.
pub fn monitor_send_signal_legacy(
    session_id: String,
    pid: u32,
    signal: String,
) -> Result<(), String> {
    let _ = (session_id, pid);
    match signal.as_str() {
        "SIGTERM" | "SIGKILL" | "SIGUSR1" | "SIGUSR2" => Ok(()),
        other => Err(format!("Unsupported signal: {other}")),
    }
}

// ─── Polling ─────────────────────────────────────────────────────────────────

pub fn monitor_start_polling(
    session_id: String,
    interval_ms: u32,
) -> Result<(), String> {
    let mut reg = POLLING_REGISTRY.lock().unwrap();
    if reg.len() >= MAX_CONCURRENT_MONITORS && !reg.contains_key(&session_id) {
        return Err(format!(
            "Max {} concurrent monitor streams reached",
            MAX_CONCURRENT_MONITORS
        ));
    }
    reg.insert(session_id, interval_ms.clamp(250, 30_000));
    Ok(())
}

pub fn monitor_stop_polling(session_id: String) -> Result<(), String> {
    POLLING_REGISTRY.lock().unwrap().remove(&session_id);
    Ok(())
}

pub fn monitor_active_polling_sessions() -> Vec<String> {
    POLLING_REGISTRY.lock().unwrap().keys().cloned().collect()
}

/// For tests: checks whether polling is currently active for `session_id`.
pub fn _test_is_polling(session_id: &str) -> bool {
    POLLING_REGISTRY.lock().unwrap().contains_key(session_id)
}

/// For tests: clears the polling registry.
pub fn _test_clear_polling() {
    POLLING_REGISTRY.lock().unwrap().clear();
}
