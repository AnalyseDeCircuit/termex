use termex_flutter_bridge::api::monitor::*;

// ─── SystemStats ─────────────────────────────────────────────────────────────

#[test]
fn test_monitor_get_stats_returns_defaults() {
    let stats = monitor_get_stats("session-1".into()).unwrap();
    assert_eq!(stats.cpu_percent, 0.0);
    assert_eq!(stats.mem_used_mb, 0);
    assert_eq!(stats.mem_total_mb, 0);
    assert_eq!(stats.disk_used_gb, 0.0);
    assert_eq!(stats.disk_total_gb, 0.0);
    assert_eq!(stats.net_rx_bytes, 0);
    assert_eq!(stats.net_tx_bytes, 0);
    assert!(!stats.timestamp.is_empty(), "timestamp should be set");
}

#[test]
fn test_monitor_get_stats_timestamp_is_iso8601() {
    let stats = monitor_get_stats("session-ts".into()).unwrap();
    assert!(
        stats.timestamp.contains('T'),
        "timestamp should be ISO 8601, got: {}",
        stats.timestamp
    );
}

// ─── ProcessInfo ─────────────────────────────────────────────────────────────

#[test]
fn test_monitor_list_processes_returns_empty() {
    let procs = monitor_list_processes("session-proc".into(), 10).unwrap();
    assert!(procs.is_empty());
}

#[test]
fn test_monitor_list_processes_zero_limit() {
    let procs = monitor_list_processes("session-zero".into(), 0).unwrap();
    assert!(procs.is_empty());
}

// ─── Signals (legacy 3-arg path) ─────────────────────────────────────────────

#[test]
fn test_monitor_send_signal_legacy_valid_sigterm() {
    monitor_send_signal_legacy("session-sig".into(), 1234, "SIGTERM".into()).unwrap();
}

#[test]
fn test_monitor_send_signal_legacy_valid_sigkill() {
    monitor_send_signal_legacy("session-sig".into(), 5678, "SIGKILL".into()).unwrap();
}

#[test]
fn test_monitor_send_signal_legacy_valid_sigusr() {
    monitor_send_signal_legacy("session-sig".into(), 9000, "SIGUSR1".into()).unwrap();
    monitor_send_signal_legacy("session-sig".into(), 9001, "SIGUSR2".into()).unwrap();
}

#[test]
fn test_monitor_send_signal_legacy_invalid() {
    let err = monitor_send_signal_legacy("session-sig".into(), 1, "SIGFOO".into())
        .unwrap_err();
    assert!(err.contains("Unsupported signal"), "got: {err}");
    assert!(err.contains("SIGFOO"), "got: {err}");
}

// ─── Polling ─────────────────────────────────────────────────────────────────

#[test]
fn test_monitor_start_stop_polling_ok() {
    let sid = "session-poll".to_string();
    _test_clear_polling();
    monitor_start_polling(sid.clone(), 1000).unwrap();
    assert!(_test_is_polling(&sid), "polling should be active after start");
    monitor_stop_polling(sid.clone()).unwrap();
    assert!(!_test_is_polling(&sid), "polling should stop after stop");
}
