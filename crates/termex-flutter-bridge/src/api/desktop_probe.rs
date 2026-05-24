//! FRB bridge for the v0.76.0 desktop daemon-probe classifier.
//! Pure stateless wrappers — no database, no SSH — just exposes the
//! probe enum + classifier + batch summary to Dart so the
//! DesktopDaemonOrchestrator can render the MissingDaemonsBanner
//! without duplicating logic in two languages.

use serde::{Deserialize, Serialize};

use termex_core::desktop::probe::{
    classify_probe, probe_batch_summary, DaemonProbe as CoreProbe, ProbeBatchSummary as CoreSummary,
    ProbeOutcome, ServerProbeResult, MIN_TERMEXD_VERSION as CORE_MIN_VERSION,
};

/// Mirror of `termex_core::desktop::probe::DaemonProbe` flattened
/// for the FRB wire (Dart doesn't get the tagged enum directly —
/// flatten avoids a wrapper class).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DesktopDaemonProbeDto {
    /// "available" / "not_installed" / "unreachable" / "outdated" / "protocol_error".
    pub kind: String,
    /// Populated only for Available / Outdated.
    pub version: Option<String>,
    /// Populated only for Outdated.
    pub min_version: Option<String>,
}

impl From<CoreProbe> for DesktopDaemonProbeDto {
    fn from(p: CoreProbe) -> Self {
        match p {
            CoreProbe::Available { version } => Self {
                kind: "available".into(),
                version: Some(version),
                min_version: None,
            },
            CoreProbe::NotInstalled => Self {
                kind: "not_installed".into(),
                version: None,
                min_version: None,
            },
            CoreProbe::Unreachable => Self {
                kind: "unreachable".into(),
                version: None,
                min_version: None,
            },
            CoreProbe::Outdated {
                version,
                min_version,
            } => Self {
                kind: "outdated".into(),
                version: Some(version),
                min_version: Some(min_version),
            },
            CoreProbe::ProtocolError => Self {
                kind: "protocol_error".into(),
                version: None,
                min_version: None,
            },
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServerProbeResultDto {
    pub server_id: String,
    pub probe: DesktopDaemonProbeDto,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProbeBatchSummaryDto {
    pub total: u32,
    pub available: u32,
    pub not_installed: u32,
    pub unreachable: u32,
    pub outdated: u32,
    pub protocol_error: u32,
    pub any_available: bool,
}

impl From<CoreSummary> for ProbeBatchSummaryDto {
    fn from(s: CoreSummary) -> Self {
        let any_available = s.any_available();
        Self {
            total: s.total as u32,
            available: s.available as u32,
            not_installed: s.not_installed as u32,
            unreachable: s.unreachable as u32,
            outdated: s.outdated as u32,
            protocol_error: s.protocol_error as u32,
            any_available,
        }
    }
}

/// Classify a single probe outcome. The Dart side calls this after
/// it has already run the SSH probe and learned which bucket the
/// outcome falls into.
///
/// `outcome` is one of: `"handshake_ok"`, `"not_reachable"`,
/// `"binary_missing"`, `"protocol_error"`. For `handshake_ok` the
/// `version` parameter is required; otherwise it is ignored.
pub fn desktop_probe_classify(
    outcome: String,
    version: Option<String>,
) -> Result<DesktopDaemonProbeDto, String> {
    let core_outcome = match outcome.as_str() {
        "handshake_ok" => ProbeOutcome::HandshakeOk {
            version: version.ok_or("version required for handshake_ok outcome")?,
        },
        "not_reachable" => ProbeOutcome::NotReachable,
        "binary_missing" => ProbeOutcome::BinaryMissing,
        "protocol_error" => ProbeOutcome::ProtocolError,
        other => return Err(format!("unknown probe outcome: {other}")),
    };
    Ok(classify_probe(core_outcome).into())
}

/// Fold a batch of per-server results into the summary used by the
/// MissingDaemonsBanner widget.
pub fn desktop_probe_summary(
    results: Vec<ServerProbeResultDto>,
) -> Result<ProbeBatchSummaryDto, String> {
    let core_results: Vec<ServerProbeResult> = results
        .into_iter()
        .map(|dto| {
            let probe = match dto.probe.kind.as_str() {
                "available" => CoreProbe::Available {
                    version: dto.probe.version.unwrap_or_default(),
                },
                "not_installed" => CoreProbe::NotInstalled,
                "unreachable" => CoreProbe::Unreachable,
                "outdated" => CoreProbe::Outdated {
                    version: dto.probe.version.unwrap_or_default(),
                    min_version: dto.probe.min_version.unwrap_or_default(),
                },
                "protocol_error" => CoreProbe::ProtocolError,
                _ => CoreProbe::ProtocolError,
            };
            Ok::<_, String>(ServerProbeResult {
                server_id: dto.server_id,
                probe,
            })
        })
        .collect::<Result<_, _>>()?;
    Ok(probe_batch_summary(&core_results).into())
}

/// Constant the Dart side can read so the UI labels stay in sync
/// with whatever the Rust core requires.
pub fn desktop_probe_min_version() -> String {
    CORE_MIN_VERSION.to_string()
}
