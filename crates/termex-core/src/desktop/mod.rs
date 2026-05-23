//! Desktop-shell support primitives used by the v0.76.0 PC
//! integration. The Rust core ships the testable pieces: a probe
//! classifier that turns a connect-attempt outcome into a
//! `DaemonProbe` state, and a semver gate for "is the remote
//! daemon recent enough?". The Flutter side composes these via
//! the bridge into the DesktopDaemonOrchestrator.

pub mod probe;

pub use probe::{
    classify_probe, probe_batch_summary, ProbeBatchSummary, ProbeError, ProbeOutcome,
    DaemonProbe, ServerProbeResult, MIN_TERMEXD_VERSION,
};
