use std::sync::Arc;

use tauri::State;
use tokio::sync::RwLock;

use crate::monitor::collector::{self, CollectorCommand, MetricsHistory};
use crate::monitor::types::SystemMetrics;
use crate::state::AppState;

/// Starts monitor collection for the given session.
///
/// Reuses the existing SSH session's exec channel for metric collection.
/// If the session is already being monitored, stops the old collector first.
#[tauri::command]
pub async fn monitor_start(
    state: State<'_, AppState>,
    app: tauri::AppHandle,
    session_id: String,
    interval_ms: Option<u64>,
) -> Result<(), String> {
    #[cfg(not(feature = "private"))]
    {
        let _ = (state, app, session_id, interval_ms);
        return Err("monitor requires the commercial build".into());
    }
    #[cfg(feature = "private")]
    {
        let interval = interval_ms.unwrap_or(3000).max(1000);

        // Stop existing collector if any
        monitor_stop_inner(&state, &session_id).await;

        // Verify session exists
        {
            let sessions = state.sessions.read().await;
            if !sessions.contains_key(&session_id) {
                return Err(format!("session not found: {session_id}"));
            }
        }

        // Create history ring buffer (5min / interval)
        let capacity = (300_000 / interval) as usize;
        let history = Arc::new(RwLock::new(MetricsHistory::new(capacity.max(10))));

        // Spawn collector using AppHandle to access state
        let collector = spawn_collector_via_app(
            app.clone(),
            session_id.clone(),
            interval,
            history.clone(),
        );

        // Register in state
        {
            let mut collectors = state.monitor_collectors.write().await;
            collectors.insert(session_id.clone(), collector);
        }
        {
            let mut histories = state.monitor_history.write().await;
            histories.insert(session_id, history);
        }

        Ok(())
    }
}

/// Spawns a collector that accesses sessions via AppHandle.
#[cfg(feature = "private")]
fn spawn_collector_via_app(
    app: tauri::AppHandle,
    session_id: String,
    interval_ms: u64,
    history: Arc<RwLock<MetricsHistory>>,
) -> crate::monitor::CollectorState {
    use std::collections::HashMap;
    use std::time::Instant;
    use tauri::{Emitter, Manager};
    use tokio::time::Duration;
    use crate::monitor::{parser, types::*};

    let (cmd_tx, mut cmd_rx) = tokio::sync::mpsc::unbounded_channel::<CollectorCommand>();
    let sid = session_id.clone();

    let task_handle = tokio::spawn(async move {
        let state = match app.try_state::<AppState>() {
            Some(s) => s,
            None => return,
        };

        // 1. Detect OS type
        let os_type = {
            let sessions_guard = state.sessions.read().await;
            let session = match sessions_guard.get(&sid) {
                Some(s) => s,
                None => return,
            };
            match session.exec_command("uname -s").await {
                Ok((output, _)) => match output.trim() {
                    "Linux" => ServerOS::Linux,
                    "Darwin" => ServerOS::MacOS,
                    "FreeBSD" => ServerOS::FreeBSD,
                    _ => ServerOS::Unknown,
                },
                Err(_) => ServerOS::Unknown,
            }
        };

        // 2. Collect OS info (one-time)
        let os_info = collector::collect_os_info_via_state(&state.sessions, &sid, os_type).await;

        let event = format!("monitor://os-info/{sid}");
        let _ = app.emit(&event, &os_info);

        // 3. Periodic collection
        let mut prev_cpu: Option<RawCpuCounters> = None;
        let mut prev_net: HashMap<String, RawNetworkCounters> = HashMap::new();
        let mut prev_time = Instant::now();
        let mut interval = tokio::time::interval(Duration::from_millis(interval_ms));

        loop {
            tokio::select! {
                _ = interval.tick() => {
                    let now = Instant::now();
                    let elapsed_secs = now.duration_since(prev_time).as_secs_f64();
                    prev_time = now;

                    let batch_cmd = collector::build_batch_command(os_type);
                    let exec_timeout = interval_ms.saturating_sub(500).max(2000);

                    let output = {
                        let sessions_guard = state.sessions.read().await;
                        let session = match sessions_guard.get(&sid) {
                            Some(s) => s,
                            None => break,
                        };
                        collector::exec_with_timeout(session, &batch_cmd, exec_timeout).await
                    };

                    match output {
                        Ok((stdout, _)) => {
                            let sections = collector::split_sections(&stdout);

                            let (mut cpu, raw_cpu) = parser::parse_cpu(
                                os_type,
                                sections.get("CPU").unwrap_or(&String::new()),
                                prev_cpu.as_ref(),
                            );
                            cpu.core_count = os_info.core_count;

                            let memory = parser::parse_memory(
                                os_type,
                                sections.get("MEM").unwrap_or(&String::new()),
                            );
                            let disk = parser::parse_disk(
                                os_type,
                                sections.get("DISK").unwrap_or(&String::new()),
                            );
                            let (network, raw_net) = parser::parse_network(
                                os_type,
                                sections.get("NET").unwrap_or(&String::new()),
                                &prev_net,
                                elapsed_secs,
                            );
                            let load = parser::parse_load(
                                os_type,
                                sections.get("LOAD").unwrap_or(&String::new()),
                            );
                            let uptime = parser::parse_uptime(
                                os_type,
                                sections.get("UPTIME").unwrap_or(&String::new()),
                            );
                            let top_cpu = parser::parse_processes(
                                sections.get("PROCS_CPU").unwrap_or(&String::new()),
                            );
                            let top_mem = parser::parse_processes(
                                sections.get("PROCS_MEM").unwrap_or(&String::new()),
                            );

                            prev_cpu = raw_cpu;
                            prev_net = raw_net;

                            let metrics = SystemMetrics {
                                timestamp: ::time::OffsetDateTime::now_utc().unix_timestamp() * 1000,
                                cpu,
                                memory,
                                disk,
                                network,
                                load,
                                uptime_seconds: uptime,
                                top_cpu_processes: top_cpu,
                                top_mem_processes: top_mem,
                            };

                            {
                                let mut hist = history.write().await;
                                hist.push(metrics.clone());
                            }

                            let event = format!("monitor://metrics/{sid}");
                            let _ = app.emit(&event, &metrics);
                        }
                        Err(e) => {
                            let event = format!("monitor://error/{sid}");
                            let _ = app.emit(&event, &e);
                        }
                    }
                }

                cmd = cmd_rx.recv() => {
                    match cmd {
                        Some(CollectorCommand::SetInterval(ms)) => {
                            interval = tokio::time::interval(Duration::from_millis(ms));
                        }
                        Some(CollectorCommand::Stop) | None => break,
                    }
                }
            }
        }
    });

    crate::monitor::CollectorState { cmd_tx, task_handle }
}

/// Stops monitor collection for the given session.
#[tauri::command]
pub async fn monitor_stop(
    state: State<'_, AppState>,
    session_id: String,
) -> Result<(), String> {
    monitor_stop_inner(&state, &session_id).await;
    Ok(())
}

/// Internal stop helper, also used by ssh_disconnect.
pub async fn monitor_stop_inner(state: &AppState, session_id: &str) {
    {
        let mut collectors = state.monitor_collectors.write().await;
        if let Some(collector) = collectors.remove(session_id) {
            let _ = collector.cmd_tx.send(CollectorCommand::Stop);
            let _ = tokio::time::timeout(
                std::time::Duration::from_secs(5),
                collector.task_handle,
            )
            .await;
        }
    }
    {
        let mut histories = state.monitor_history.write().await;
        histories.remove(session_id);
    }
}

/// Returns the latest metrics snapshot for a session.
#[tauri::command]
pub async fn monitor_get_latest(
    state: State<'_, AppState>,
    session_id: String,
) -> Result<Option<SystemMetrics>, String> {
    let histories = state.monitor_history.read().await;
    if let Some(history) = histories.get(&session_id) {
        let hist = history.read().await;
        Ok(hist.latest().cloned())
    } else {
        Ok(None)
    }
}

/// Returns historical metrics within a time range (for chart rendering).
#[tauri::command]
pub async fn monitor_get_history(
    state: State<'_, AppState>,
    session_id: String,
    duration_secs: Option<u64>,
) -> Result<Vec<SystemMetrics>, String> {
    let duration = duration_secs.unwrap_or(300);
    let histories = state.monitor_history.read().await;
    if let Some(history) = histories.get(&session_id) {
        let hist = history.read().await;
        Ok(hist.range(duration))
    } else {
        Ok(Vec::new())
    }
}
