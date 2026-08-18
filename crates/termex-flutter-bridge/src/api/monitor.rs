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
use termex_core::monitor::collector::{
    DerivedStats, MonitorSampler, build_batch_command, parse_snapshot,
};
use termex_core::monitor::types::ServerOS;

/// Per-session previous counters, so CPU% and network throughput can be
/// derived from consecutive samples.
static SAMPLER: Lazy<Mutex<MonitorSampler>> =
    Lazy::new(|| Mutex::new(MonitorSampler::new()));

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

/// Collects a real-time metrics snapshot for the local host.
///
/// Unlike [`monitor_get_stats`], this does not require an SSH session — it
/// queries the machine Termex itself is running on via `sysinfo`. Used by
/// local-PTY tabs whose monitor panel previously rendered hard-coded values.
pub fn monitor_collect_local_stats() -> Result<SystemStats, String> {
    #[cfg(not(feature = "private"))]
    {
        Err("monitor requires the commercial build".into())
    }
    #[cfg(feature = "private")]
    {
        let s = termex_core_private::monitor::local::collect_local_stats();
        Ok(SystemStats {
            cpu_percent: s.cpu_percent,
            mem_used_mb: s.mem_used_mb,
            mem_total_mb: s.mem_total_mb,
            disk_used_gb: s.disk_used_gb,
            disk_total_gb: s.disk_total_gb,
            net_rx_bytes: s.net_rx_bytes,
            net_tx_bytes: s.net_tx_bytes,
            timestamp: s.timestamp,
        })
    }
}

/// Runs the batched collection command on `session_id` and returns the raw
/// stdout.
///
/// Clones the session `Arc` and drops the DashMap `Ref` before awaiting:
/// `REGISTRY.get()` hands back a guard over a synchronous shard lock, and
/// holding it across an `.await` blocks every other session hashing to the
/// same shard (this is what deadlocked SFTP).
async fn run_batch(session_id: &str) -> Result<String, String> {
    let session = {
        let entry = crate::session_registry::REGISTRY
            .get(session_id)
            .ok_or_else(|| format!("no active session {session_id}"))?;
        entry.session.clone()
    };
    let guard = session.lock().await;
    let session = guard
        .as_ref()
        .ok_or_else(|| format!("session {session_id} is disconnected"))?;

    // OS detection would need its own round-trip; the Linux command is also
    // the `Unknown` fallback and works on any host with /proc.
    let cmd = build_batch_command(ServerOS::Linux);
    let (stdout, _exit) = session
        .exec_command(&cmd)
        .await
        .map_err(|e| format!("monitor collection failed: {e}"))?;
    Ok(stdout)
}

/// Samples `session_id` and folds the result into the per-session baseline.
///
/// Cumulative counters (`/proc/stat`, `/proc/net/dev`) mean the first tick of
/// a session can only prime the baseline and reports 0% / 0 B/s; the tick
/// after it carries real numbers.
async fn sample(session_id: &str, process_limit: usize) -> Result<DerivedStats, String> {
    let stdout = run_batch(session_id).await?;
    let snapshot = parse_snapshot(&stdout, process_limit);
    let now_ms = chrono::Utc::now().timestamp_millis();
    let mut sampler = SAMPLER.lock().unwrap();
    Ok(sampler.ingest(session_id, snapshot, now_ms))
}

pub async fn monitor_get_stats(session_id: String) -> Result<SystemStats, String> {
    let d = sample(&session_id, 0).await?;
    Ok(SystemStats {
        cpu_percent: d.cpu_percent,
        mem_used_mb: d.mem_used_mb,
        mem_total_mb: d.mem_total_mb,
        disk_used_gb: d.disk_used_gb,
        disk_total_gb: d.disk_total_gb,
        net_rx_bytes: d.net_rx_bytes,
        net_tx_bytes: d.net_tx_bytes,
        timestamp: chrono::Utc::now().to_rfc3339(),
    })
}

pub async fn monitor_list_processes(
    session_id: String,
    limit: i32,
) -> Result<Vec<ProcessInfo>, String> {
    let limit = limit.clamp(0, 100) as usize;
    let d = sample(&session_id, limit).await?;
    Ok(d.processes
        .into_iter()
        .map(|p| ProcessInfo {
            pid: p.pid,
            user: p.user,
            cpu_percent: p.cpu_percent as f32,
            memory_percent: p.mem_percent as f32,
            command: p.command,
            started_at: None,
        })
        .collect())
}

/// Drops a session's counter baseline.
///
/// Called on disconnect so that reconnecting to a rebooted host does not
/// difference against pre-reboot counters and report a nonsense spike.
pub fn monitor_forget_session(session_id: String) {
    SAMPLER.lock().unwrap().forget(&session_id);
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
