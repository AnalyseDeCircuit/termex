//! Chain-connect orchestrator with per-hop retry + reverse cleanup (v0.68.0 G3).
//!
//! The runtime SSH path in v0.68.x still calls `connect_direct` for the
//! single-hop case; this module supplies the chained variant the v0.69+
//! integration will plug into. Two pieces of value land *today*:
//!
//! 1. The full retry / cleanup state machine, exercised by unit tests so
//!    the algorithm is validated independently of any real TCP.
//! 2. A `ChainProgress` event stream the bridge can pump into Dart, giving
//!    the reconnect banner a real source of hop progress events even
//!    while the actual connector is still a mock.
//!
//! When the SSH-jump multiplex transport arrives the consumer just hands
//! `chain_connect_with` a real connector closure and inherits all of the
//! retry / event behaviour exercised here.

use std::time::Duration;

use tokio::sync::mpsc;

/// One step in the chain. `name` is what surfaces in the UI banner.
#[derive(Debug, Clone)]
pub struct HopConfig {
    pub hop_id: String,
    pub name: String,
    pub host: String,
    pub port: u16,
}

/// Retry policy + the ordered list of hops.
#[derive(Debug, Clone)]
pub struct ChainConnectConfig {
    pub hops: Vec<HopConfig>,
    pub max_retries_per_hop: u32,
    pub backoff_base_ms: u64,
    pub backoff_max_ms: u64,
}

impl ChainConnectConfig {
    pub fn new(hops: Vec<HopConfig>) -> Self {
        Self {
            hops,
            max_retries_per_hop: 3,
            backoff_base_ms: 500,
            backoff_max_ms: 8000,
        }
    }
}

/// Lifecycle events emitted as the chain is built. Bridge polls these
/// from a per-session queue and surfaces them in Dart.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ChainProgress {
    /// About to attempt a connect to hop `hop_index` (0-based).
    Connecting {
        hop_index: u32,
        hop_total: u32,
        hop_name: String,
        attempt: u32,
    },
    /// Hop succeeded — moving on.
    HopConnected {
        hop_index: u32,
        hop_total: u32,
        hop_name: String,
        elapsed_ms: u64,
    },
    /// Hop failed. `will_retry == true` means another attempt is queued;
    /// false means the chain is about to fail.
    HopFailed {
        hop_index: u32,
        hop_name: String,
        attempt: u32,
        error: String,
        will_retry: bool,
        next_attempt_in_ms: u64,
    },
    /// All retries for the current hop are exhausted; chain aborted.
    ChainFailed {
        failed_at_hop: u32,
        hop_name: String,
        error: String,
    },
    /// Every hop connected.
    ChainConnected { total_elapsed_ms: u64 },
}

/// Opaque per-hop session handle the user-provided connector returns.
/// The chain orchestrator only needs to be able to *close* them in
/// reverse order on failure; the concrete shape is up to the caller.
pub trait HopSession: Send + 'static {
    fn close_boxed(self: Box<Self>);
}

/// Final result of a successful chain — every hop's session, in order.
/// Caller owns the lifetime and is responsible for tearing them down on
/// disconnect.
pub struct ChainSession {
    pub hops: Vec<Box<dyn HopSession>>,
}

/// Computes exponential backoff with a cap: `min(base * 2^attempt, max)`.
/// `attempt` is 0-based — the first retry uses `base`, the second `base * 2`,
/// and so on, capped at `backoff_max_ms`.
pub fn backoff_ms(cfg: &ChainConnectConfig, attempt: u32) -> u64 {
    let shifted = (cfg.backoff_base_ms as u128) << attempt.min(20);
    shifted.min(cfg.backoff_max_ms as u128) as u64
}

/// Runs the chain. `connector` is invoked once per attempt for each hop —
/// it gets the hop config and returns either a hop session (success) or an
/// error string. The orchestrator handles retry / sleep / cleanup so the
/// caller stays focused on the actual transport.
///
/// The test suite injects a deterministic connector that returns scripted
/// successes and failures; the bridge integration uses an `ssh::session`
/// builder closure.
pub async fn chain_connect_with<F, Fut>(
    config: &ChainConnectConfig,
    mut connector: F,
    progress: mpsc::UnboundedSender<ChainProgress>,
) -> Result<ChainSession, String>
where
    F: FnMut(&HopConfig, u32) -> Fut + Send,
    Fut: std::future::Future<Output = Result<Box<dyn HopSession>, String>> + Send,
{
    let hop_total = config.hops.len() as u32;
    let chain_started = std::time::Instant::now();
    let mut acquired: Vec<Box<dyn HopSession>> = Vec::with_capacity(config.hops.len());

    for (i, hop) in config.hops.iter().enumerate() {
        let hop_index = i as u32;
        let mut attempt: u32 = 0;
        loop {
            let _ = progress.send(ChainProgress::Connecting {
                hop_index,
                hop_total,
                hop_name: hop.name.clone(),
                attempt,
            });

            let hop_started = std::time::Instant::now();
            let result = connector(hop, attempt).await;
            match result {
                Ok(session) => {
                    let _ = progress.send(ChainProgress::HopConnected {
                        hop_index,
                        hop_total,
                        hop_name: hop.name.clone(),
                        elapsed_ms: hop_started.elapsed().as_millis() as u64,
                    });
                    acquired.push(session);
                    break;
                }
                Err(err) => {
                    attempt += 1;
                    let exhausted = attempt > config.max_retries_per_hop;
                    let will_retry = !exhausted;
                    let next_ms = if will_retry { backoff_ms(config, attempt - 1) } else { 0 };
                    let _ = progress.send(ChainProgress::HopFailed {
                        hop_index,
                        hop_name: hop.name.clone(),
                        attempt,
                        error: err.clone(),
                        will_retry,
                        next_attempt_in_ms: next_ms,
                    });
                    if exhausted {
                        // Reverse-close every hop we already built.
                        while let Some(s) = acquired.pop() {
                            s.close_boxed();
                        }
                        let _ = progress.send(ChainProgress::ChainFailed {
                            failed_at_hop: hop_index,
                            hop_name: hop.name.clone(),
                            error: err.clone(),
                        });
                        return Err(err);
                    }
                    tokio::time::sleep(Duration::from_millis(next_ms)).await;
                }
            }
        }
    }

    let _ = progress.send(ChainProgress::ChainConnected {
        total_elapsed_ms: chain_started.elapsed().as_millis() as u64,
    });
    Ok(ChainSession { hops: acquired })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Arc;

    /// Test hop session that increments a counter on close — lets the
    /// reverse-cleanup assertion verify every acquired session was closed.
    struct CountingSession {
        on_close: Arc<AtomicUsize>,
    }
    impl HopSession for CountingSession {
        fn close_boxed(self: Box<Self>) {
            self.on_close.fetch_add(1, Ordering::SeqCst);
        }
    }

    fn three_hops() -> ChainConnectConfig {
        let hops = vec![
            HopConfig { hop_id: "a".into(), name: "bastion-1".into(), host: "h1".into(), port: 22 },
            HopConfig { hop_id: "b".into(), name: "bastion-2".into(), host: "h2".into(), port: 22 },
            HopConfig { hop_id: "c".into(), name: "target".into(),    host: "h3".into(), port: 22 },
        ];
        let mut cfg = ChainConnectConfig::new(hops);
        cfg.backoff_base_ms = 1;
        cfg.backoff_max_ms = 4;
        cfg
    }

    fn drain(rx: &mut mpsc::UnboundedReceiver<ChainProgress>) -> Vec<ChainProgress> {
        let mut out = Vec::new();
        while let Ok(e) = rx.try_recv() {
            out.push(e);
        }
        out
    }

    #[tokio::test]
    async fn backoff_caps_at_max() {
        let mut cfg = ChainConnectConfig::new(vec![]);
        cfg.backoff_base_ms = 500;
        cfg.backoff_max_ms = 8000;
        assert_eq!(backoff_ms(&cfg, 0), 500);
        assert_eq!(backoff_ms(&cfg, 1), 1000);
        assert_eq!(backoff_ms(&cfg, 2), 2000);
        assert_eq!(backoff_ms(&cfg, 3), 4000);
        assert_eq!(backoff_ms(&cfg, 4), 8000);
        assert_eq!(backoff_ms(&cfg, 5), 8000, "saturates at max");
        assert_eq!(backoff_ms(&cfg, 20), 8000, "still saturated");
    }

    #[tokio::test]
    async fn happy_path_emits_one_event_per_hop() {
        let cfg = three_hops();
        let close_count = Arc::new(AtomicUsize::new(0));
        let cc = close_count.clone();
        let (tx, mut rx) = mpsc::unbounded_channel();

        let result = chain_connect_with(
            &cfg,
            |_hop, _attempt| {
                let cc = cc.clone();
                async move {
                    Ok(Box::new(CountingSession { on_close: cc }) as Box<dyn HopSession>)
                }
            },
            tx,
        )
        .await;

        let session = result.unwrap();
        assert_eq!(session.hops.len(), 3);
        let events = drain(&mut rx);
        // Connecting + HopConnected per hop + ChainConnected
        assert_eq!(events.len(), 7);
        assert!(matches!(events[0], ChainProgress::Connecting { hop_index: 0, attempt: 0, .. }));
        assert!(matches!(events[1], ChainProgress::HopConnected { hop_index: 0, .. }));
        assert!(matches!(events[6], ChainProgress::ChainConnected { .. }));
        assert_eq!(close_count.load(Ordering::SeqCst), 0, "no hop closed on success");
    }

    #[tokio::test]
    async fn retries_then_succeeds() {
        let cfg = three_hops();
        let close_count = Arc::new(AtomicUsize::new(0));
        let cc = close_count.clone();
        let attempts = Arc::new(AtomicUsize::new(0));
        let ac = attempts.clone();
        let (tx, mut rx) = mpsc::unbounded_channel();

        let result = chain_connect_with(
            &cfg,
            move |hop, attempt| {
                let cc = cc.clone();
                let ac = ac.clone();
                let host = hop.host.clone();
                async move {
                    if host == "h2" && attempt < 2 {
                        ac.fetch_add(1, Ordering::SeqCst);
                        Err(format!("simulated failure attempt {attempt}"))
                    } else {
                        Ok(Box::new(CountingSession { on_close: cc }) as Box<dyn HopSession>)
                    }
                }
            },
            tx,
        )
        .await;

        assert!(result.is_ok(), "should retry through transient failures");
        let events = drain(&mut rx);
        let failed: Vec<_> = events
            .iter()
            .filter(|e| matches!(e, ChainProgress::HopFailed { will_retry: true, .. }))
            .collect();
        assert_eq!(failed.len(), 2, "two retries before success");
        assert_eq!(attempts.load(Ordering::SeqCst), 2);
    }

    #[tokio::test]
    async fn exhaust_retries_aborts_with_cleanup() {
        let cfg = three_hops();
        let close_count = Arc::new(AtomicUsize::new(0));
        let cc = close_count.clone();
        let (tx, mut rx) = mpsc::unbounded_channel();

        let result = chain_connect_with(
            &cfg,
            move |hop, _attempt| {
                let cc = cc.clone();
                let host = hop.host.clone();
                async move {
                    if host == "h2" {
                        Err("permanent failure".to_string())
                    } else {
                        Ok(Box::new(CountingSession { on_close: cc }) as Box<dyn HopSession>)
                    }
                }
            },
            tx,
        )
        .await;

        assert!(result.is_err());
        // hop 0 succeeded once and should be reverse-closed.
        assert_eq!(close_count.load(Ordering::SeqCst), 1);
        let events = drain(&mut rx);
        let final_fail = events.iter().any(|e| {
            matches!(e, ChainProgress::ChainFailed { failed_at_hop: 1, .. })
        });
        assert!(final_fail, "ChainFailed must reference the failing hop");

        // Last HopFailed should be will_retry: false.
        let last_failed = events
            .iter()
            .rev()
            .find(|e| matches!(e, ChainProgress::HopFailed { .. }))
            .unwrap();
        assert!(matches!(
            last_failed,
            ChainProgress::HopFailed { will_retry: false, .. }
        ));
    }

    #[tokio::test]
    async fn first_hop_failure_does_not_open_later_hops() {
        let cfg = three_hops();
        let attempt_log = Arc::new(AtomicUsize::new(0));
        let al = attempt_log.clone();
        let (tx, _rx) = mpsc::unbounded_channel();

        let _ = chain_connect_with(
            &cfg,
            move |_hop, _attempt| {
                let al = al.clone();
                async move {
                    al.fetch_add(1, Ordering::SeqCst);
                    Err::<Box<dyn HopSession>, _>("fail".to_string())
                }
            },
            tx,
        )
        .await;

        // hop 0 attempted 4 times (initial + 3 retries); the algorithm
        // must not advance to hop 1 if hop 0 cannot connect.
        assert_eq!(attempt_log.load(Ordering::SeqCst), 4);
    }
}
