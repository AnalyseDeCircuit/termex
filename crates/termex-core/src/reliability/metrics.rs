//! Pure update helpers — each takes the current metrics + an
//! observation and returns the new metrics. Separating these from
//! the storage layer keeps them trivially testable and lets the
//! Flutter side reuse the exact same semantics over the bridge.

use saturating::Saturating;

use super::TaskMetrics;

/// Tiny trait shim so we can use `wrapping_add`-style saturating
/// math without pulling in num_traits.
mod saturating {
    pub trait Saturating {
        fn sat_add(self, other: Self) -> Self;
    }
    impl Saturating for u64 {
        fn sat_add(self, other: Self) -> Self {
            self.saturating_add(other)
        }
    }
    impl Saturating for u32 {
        fn sat_add(self, other: Self) -> Self {
            self.saturating_add(other)
        }
    }
}

/// Accumulate a finished WebSocket session of `duration_ms` and
/// stamp `now_rfc3339`.
pub fn record_ws_session(
    m: &TaskMetrics,
    duration_ms: u64,
    now_rfc3339: impl Into<String>,
) -> TaskMetrics {
    TaskMetrics {
        ws_uptime_ms: m.ws_uptime_ms.sat_add(duration_ms),
        updated_at: now_rfc3339.into(),
        ..m.clone()
    }
}

/// Increment the reconnect counter by 1.
pub fn record_reconnect(m: &TaskMetrics, now_rfc3339: impl Into<String>) -> TaskMetrics {
    TaskMetrics {
        reconnect_count: m.reconnect_count.sat_add(1),
        updated_at: now_rfc3339.into(),
        ..m.clone()
    }
}

/// Accumulate a finished background-foreground gap of `duration_ms`.
pub fn record_bg_duration(
    m: &TaskMetrics,
    duration_ms: u64,
    now_rfc3339: impl Into<String>,
) -> TaskMetrics {
    TaskMetrics {
        bg_duration_ms: m.bg_duration_ms.sat_add(duration_ms),
        updated_at: now_rfc3339.into(),
        ..m.clone()
    }
}

/// Overwrite (not accumulate) the last-seen push latency — the UI
/// renders the *most recent* delivery delay, not the average. If a
/// future iteration wants p50/p95, switch to a streaming summary.
pub fn record_push_latency(
    m: &TaskMetrics,
    latency_ms: u32,
    now_rfc3339: impl Into<String>,
) -> TaskMetrics {
    TaskMetrics {
        push_latency_ms: Some(latency_ms),
        updated_at: now_rfc3339.into(),
        ..m.clone()
    }
}

/// Increment handoff count (each cross-device takeover bumps this).
pub fn record_handoff(m: &TaskMetrics, now_rfc3339: impl Into<String>) -> TaskMetrics {
    TaskMetrics {
        handoff_count: m.handoff_count.sat_add(1),
        updated_at: now_rfc3339.into(),
        ..m.clone()
    }
}

/// Batch helper for the reconnect path: bump `reconnect_count` for
/// every currently-subscribed task in one transaction. Each row is
/// read-modify-written; tasks without a metrics row yet get a fresh
/// `TaskMetrics::empty(...)` first.
pub fn bump_reconnect_for_tasks(
    conn: &rusqlite::Connection,
    task_ids: &[String],
    now_rfc3339: &str,
) -> Result<usize, super::ReliabilityError> {
    use super::storage::{get, save};
    use super::TaskMetrics;
    if task_ids.is_empty() {
        return Ok(0);
    }
    let tx = conn.unchecked_transaction()?;
    let mut bumped = 0usize;
    for id in task_ids {
        let current = get(&tx, id)?
            .unwrap_or_else(|| TaskMetrics::empty(id.clone(), now_rfc3339.to_string()));
        let next = record_reconnect(&current, now_rfc3339);
        save(&tx, &next)?;
        bumped += 1;
    }
    tx.commit()?;
    Ok(bumped)
}
