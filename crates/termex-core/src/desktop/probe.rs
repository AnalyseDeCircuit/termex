//! Daemon probe classifier — pure logic that turns the outcome of
//! a connect attempt against a remote `termexd` into a
//! [`DaemonProbe`] state the desktop UI can render.
//!
//! The actual SSH-tunneled WS connect lives in the bridge layer
//! (it's I/O + platform-specific transport). This module owns the
//! *decision* — given a result tuple, which bucket does the server
//! fall into? Keeping that pure makes the desktop orchestrator
//! deterministic and trivially testable, and lets us add new
//! buckets (e.g. AuthRequired) later without touching the wire.

use serde::{Deserialize, Serialize};

/// The minimum termexd version the v0.76.0 desktop client requires.
/// Bump in sync with new wire-protocol additions; if the remote
/// daemon advertises an older version we surface
/// [`DaemonProbe::Outdated`] so the user can run the in-app
/// updater rather than getting cryptic "unknown message type" RPC
/// errors at runtime.
pub const MIN_TERMEXD_VERSION: &str = "0.71.2";

/// Why the orchestrator looked up this server. Used in tracing
/// + telemetry to distinguish "we probed because user opened the
/// panel" from "we probed because the auto-orchestrator started".
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProbeError {
    /// No termexd binary on the remote — connect succeeded over
    /// SSH but the WS port refused / executable missing.
    NotInstalled,
    /// Network or SSH reachability problem (timeout, auth failure,
    /// DNS, etc.). Retry-able.
    Unreachable,
    /// WS connected and handshake succeeded, but the version
    /// string was below `MIN_TERMEXD_VERSION`.
    Outdated,
    /// Daemon spoke an unrecognized handshake / protocol error
    /// other than version — surfaced separately so we don't
    /// recommend "upgrade" for a totally foreign service.
    ProtocolError,
}

/// Outcome the bridge feeds in. The probe layer doesn't run the
/// connect itself; it interprets what the bridge observed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProbeOutcome {
    /// Handshake succeeded; daemon advertised this version string.
    HandshakeOk { version: String },
    /// Bridge could not reach the daemon at all (timeout, refused,
    /// auth fail, host unreachable, etc.).
    NotReachable,
    /// Bridge confirmed the binary is absent on the remote (the
    /// install probe found no `termexd` in PATH or systemd unit).
    BinaryMissing,
    /// Handshake landed but the response didn't parse / was wrong
    /// shape.
    ProtocolError,
}

/// Final per-server classification surfaced to the orchestrator
/// and the desktop UI banner.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case", tag = "kind")]
pub enum DaemonProbe {
    Available { version: String },
    NotInstalled,
    Unreachable,
    Outdated { version: String, min_version: String },
    ProtocolError,
}

impl DaemonProbe {
    /// True iff the desktop should try to keep an open WS
    /// connection. The orchestrator skips Unreachable / Outdated
    /// / ProtocolError to avoid hammering broken servers.
    pub fn is_usable(&self) -> bool {
        matches!(self, Self::Available { .. })
    }

    /// True iff the UI should offer an "Install termexd" CTA.
    pub fn offers_install(&self) -> bool {
        matches!(self, Self::NotInstalled)
    }

    /// True iff the UI should offer an "Upgrade termexd" CTA.
    pub fn offers_upgrade(&self) -> bool {
        matches!(self, Self::Outdated { .. })
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ServerProbeResult {
    pub server_id: String,
    pub probe: DaemonProbe,
}

/// Aggregate counts surfaced to the dev-mode footer and to the
/// `_MissingDaemonsBanner` widget. Doing this in Rust keeps the
/// Flutter side a thin pass-through and avoids re-implementing the
/// same fold in Dart.
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct ProbeBatchSummary {
    pub total: usize,
    pub available: usize,
    pub not_installed: usize,
    pub unreachable: usize,
    pub outdated: usize,
    pub protocol_error: usize,
}

impl ProbeBatchSummary {
    /// True when at least one server has a usable daemon.
    pub fn any_available(&self) -> bool {
        self.available > 0
    }
}

/// Classify a single probe outcome. The version comparison is a
/// pure semver-segment compare — sufficient for our "is at least
/// 0.71.2" gate without pulling in the full `semver` crate.
pub fn classify_probe(outcome: ProbeOutcome) -> DaemonProbe {
    match outcome {
        ProbeOutcome::HandshakeOk { version } => {
            if version_at_least(&version, MIN_TERMEXD_VERSION) {
                DaemonProbe::Available { version }
            } else {
                DaemonProbe::Outdated {
                    version,
                    min_version: MIN_TERMEXD_VERSION.to_string(),
                }
            }
        }
        ProbeOutcome::BinaryMissing => DaemonProbe::NotInstalled,
        ProbeOutcome::NotReachable => DaemonProbe::Unreachable,
        ProbeOutcome::ProtocolError => DaemonProbe::ProtocolError,
    }
}

/// Fold per-server results into the summary used by the banner.
pub fn probe_batch_summary(results: &[ServerProbeResult]) -> ProbeBatchSummary {
    let mut s = ProbeBatchSummary {
        total: results.len(),
        ..Default::default()
    };
    for r in results {
        match &r.probe {
            DaemonProbe::Available { .. } => s.available += 1,
            DaemonProbe::NotInstalled => s.not_installed += 1,
            DaemonProbe::Unreachable => s.unreachable += 1,
            DaemonProbe::Outdated { .. } => s.outdated += 1,
            DaemonProbe::ProtocolError => s.protocol_error += 1,
        }
    }
    s
}

/// True iff `actual >= min` under a 3-segment major.minor.patch
/// comparison. Trailing pre-release / build suffixes are
/// stripped (`0.71.2-dev` → `0.71.2`) so nightly daemons don't
/// trip the gate. Malformed inputs fail closed (return false) —
/// the UI shows `Outdated` rather than blindly trusting an
/// unparseable version, which mirrors how the wire-protocol
/// version check behaves if a future daemon sends garbage.
pub fn version_at_least(actual: &str, min: &str) -> bool {
    let a = parse_three_segment(actual);
    let b = parse_three_segment(min);
    match (a, b) {
        (Some(a), Some(b)) => a >= b,
        _ => false,
    }
}

fn parse_three_segment(v: &str) -> Option<(u32, u32, u32)> {
    let core = v.split(['-', '+']).next().unwrap_or(v);
    let mut it = core.split('.');
    let major = it.next()?.parse::<u32>().ok()?;
    let minor = it.next()?.parse::<u32>().ok()?;
    let patch = it.next()?.parse::<u32>().ok()?;
    if it.next().is_some() {
        return None;
    }
    Some((major, minor, patch))
}
