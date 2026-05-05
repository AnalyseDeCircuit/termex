//! Tests for the v0.47 monitor API: SystemMetrics DTOs, signal safety,
//! polling concurrency, and audit hooks.
//!
//! Polling tests share the global `POLLING_REGISTRY` with `test_api_monitor.rs`
//! and with each other, so every test that touches the registry holds
//! `POLLING_LOCK` for the duration of the test to force serial execution
//! within this binary.

use std::sync::Mutex;

use termex_flutter_bridge::api::monitor::*;

static POLLING_LOCK: Mutex<()> = Mutex::new(());

// ─── Signal validation ──────────────────────────────────────────────────────

#[test]
fn test_validate_signal_accepts_five_allowed_signals() {
    for s in ALLOWED_SIGNALS {
        monitor_validate_signal(s, 9999, "sleep", false)
            .unwrap_or_else(|e| panic!("{} should be accepted: {}", s, e));
    }
    assert_eq!(ALLOWED_SIGNALS.len(), 5);
}

#[test]
fn test_validate_signal_rejects_unknown_signal() {
    let err = monitor_validate_signal("SIGWHAT", 1234, "sleep", false)
        .unwrap_err();
    assert!(err.contains("Unsupported signal"));
    assert!(err.contains("SIGWHAT"));
}

#[test]
fn test_validate_signal_rejects_pid_0_and_1() {
    for pid in &[0u32, 1u32] {
        let err = monitor_validate_signal("SIGTERM", *pid, "anything", true)
            .unwrap_err();
        assert!(err.contains("protected"), "pid={pid} should be protected");
    }
}

#[test]
fn test_validate_signal_rejects_protected_process_names() {
    for name in PROTECTED_PROCESS_NAMES {
        let err = monitor_validate_signal("SIGTERM", 500, name, false)
            .unwrap_err();
        assert!(err.contains("protected"),
                "process '{}' should be protected without expert mode",
                name);
    }
}

#[test]
fn test_validate_signal_expert_mode_unlocks_protected_names() {
    // Expert mode can target 'systemd' (but not PID 0/1).
    monitor_validate_signal("SIGTERM", 500, "systemd", true).unwrap();
    monitor_validate_signal("SIGTERM", 500, "launchd", true).unwrap();
}

#[test]
fn test_validate_signal_expert_mode_still_blocks_pid_1() {
    let err = monitor_validate_signal("SIGKILL", 1, "systemd", true).unwrap_err();
    assert!(err.contains("protected"));
}

#[test]
fn test_send_signal_rejects_unauthorized() {
    let err = monitor_send_signal(
        "sess".into(),
        1,
        "SIGKILL".into(),
        "init".into(),
        false,
    )
    .unwrap_err();
    assert!(err.contains("protected"));
}

#[test]
fn test_send_signal_passes_validation_for_ordinary_process() {
    monitor_send_signal(
        "sess".into(),
        9999,
        "SIGTERM".into(),
        "my-app".into(),
        false,
    )
    .expect("ordinary process should accept signal");
}

// ─── Polling concurrency ────────────────────────────────────────────────────

#[test]
fn test_polling_registry_deduplicates_same_session() {
    let _lock = POLLING_LOCK.lock().unwrap();
    _test_clear_polling();
    monitor_start_polling("s1".into(), 1000).unwrap();
    monitor_start_polling("s1".into(), 500).unwrap();
    assert_eq!(monitor_active_polling_sessions().len(), 1);
    _test_clear_polling();
}

#[test]
fn test_polling_enforces_max_concurrent() {
    let _lock = POLLING_LOCK.lock().unwrap();
    _test_clear_polling();
    for i in 0..MAX_CONCURRENT_MONITORS {
        monitor_start_polling(format!("s{i}"), 1000).unwrap();
    }
    let err = monitor_start_polling("overflow".into(), 1000).unwrap_err();
    assert!(err.contains("Max"));
    assert!(err.contains(&MAX_CONCURRENT_MONITORS.to_string()));
    _test_clear_polling();
}

#[test]
fn test_polling_interval_clamped() {
    let _lock = POLLING_LOCK.lock().unwrap();
    _test_clear_polling();
    monitor_start_polling("fast".into(), 10).unwrap();
    monitor_start_polling("slow".into(), 1_000_000).unwrap();
    _test_clear_polling();
}

#[test]
fn test_polling_list_active_sessions() {
    let _lock = POLLING_LOCK.lock().unwrap();
    _test_clear_polling();
    monitor_start_polling("alpha".into(), 1000).unwrap();
    monitor_start_polling("beta".into(), 1000).unwrap();
    let list = monitor_active_polling_sessions();
    assert_eq!(list.len(), 2);
    assert!(list.contains(&"alpha".to_string()));
    assert!(list.contains(&"beta".to_string()));
    _test_clear_polling();
}

// ─── DTO smoke tests ────────────────────────────────────────────────────────

#[test]
fn test_system_metrics_struct_serializes() {
    let m = SystemMetrics {
        timestamp: "2026-04-20T00:00:00Z".into(),
        cpu: CpuMetrics {
            usage_percent: 12.5,
            load_avg_1m: 0.5,
            load_avg_5m: 0.4,
            load_avg_15m: 0.3,
            core_count: 8,
            per_core: vec![10.0, 15.0],
        },
        memory: MemoryMetrics {
            total_kb: 16 * 1024 * 1024,
            used_kb: 8 * 1024 * 1024,
            free_kb: 8 * 1024 * 1024,
            cached_kb: 1_000_000,
            swap_total_kb: 0,
            swap_used_kb: 0,
            usage_percent: 50.0,
        },
        disks: vec![DiskMetrics {
            mount_point: "/".into(),
            filesystem: "apfs".into(),
            total_kb: 500_000_000,
            used_kb: 250_000_000,
            usage_percent: 50.0,
        }],
        network: NetworkMetrics {
            rx_bytes_per_sec: 1024,
            tx_bytes_per_sec: 512,
            rx_total: 10 * 1024 * 1024,
            tx_total: 5 * 1024 * 1024,
            interfaces: vec![NetInterface {
                name: "en0".into(),
                rx_bytes: 1_000_000,
                tx_bytes: 500_000,
            }],
        },
        processes: vec![],
        uptime_seconds: 3600,
    };
    let json = serde_json::to_string(&m).unwrap();
    assert!(json.contains("\"cpu\""));
    assert!(json.contains("\"usagePercent\":12.5"));
    assert!(json.contains("\"loadAvg1m\":0.5"));
}
