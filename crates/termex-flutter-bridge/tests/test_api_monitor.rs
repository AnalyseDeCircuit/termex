use termex_flutter_bridge::api::monitor::*;

// ─── SystemStats ─────────────────────────────────────────────────────────────
//
// These used to assert that `monitor_get_stats` returned all zeros and
// `monitor_list_processes` returned an empty vec — pinning the stub that made
// the monitor panel render 0% for every gauge. Both now run a batched
// /proc + df + ps command over the session's SSH exec channel, so with no
// session registered the honest answer is an error, not a plausible-looking
// zero. Parser coverage lives in
// `crates/termex-core/tests/test_monitor_collector.rs`.

#[tokio::test]
async fn test_monitor_get_stats_errors_without_a_session() {
    let err = monitor_get_stats("session-missing".into())
        .await
        .expect_err("no session registered");
    assert!(
        err.contains("no active session"),
        "error should name the cause, got: {err}"
    );
}

#[tokio::test]
async fn test_monitor_list_processes_errors_without_a_session() {
    let err = monitor_list_processes("session-proc".into(), 10)
        .await
        .expect_err("no session registered");
    assert!(err.contains("no active session"), "got: {err}");
}

#[tokio::test]
async fn test_monitor_stats_never_reports_a_silent_zero() {
    // The whole point of the change: a collection failure must surface as an
    // error the panel can show, never as a snapshot of zeros that looks like
    // an idle host.
    assert!(monitor_get_stats("nope".into()).await.is_err());
}

#[test]
fn test_monitor_forget_session_is_safe_for_unknown_ids() {
    // Called on disconnect; must not panic for a session that never sampled.
    monitor_forget_session("never-sampled".into());
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
