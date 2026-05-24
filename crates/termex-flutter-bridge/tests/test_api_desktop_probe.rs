//! Bridge-level tests for the v0.76.0 desktop probe API.

use termex_flutter_bridge::api::desktop_probe::*;

#[test]
fn classify_handshake_above_min_returns_available() {
    let r = desktop_probe_classify("handshake_ok".into(), Some("0.99.0".into())).unwrap();
    assert_eq!(r.kind, "available");
    assert_eq!(r.version.as_deref(), Some("0.99.0"));
    assert!(r.min_version.is_none());
}

#[test]
fn classify_handshake_below_min_returns_outdated() {
    let r = desktop_probe_classify("handshake_ok".into(), Some("0.70.0".into())).unwrap();
    assert_eq!(r.kind, "outdated");
    assert_eq!(r.version.as_deref(), Some("0.70.0"));
    assert_eq!(r.min_version.as_deref(), Some(desktop_probe_min_version().as_str()));
}

#[test]
fn classify_handshake_ok_without_version_errors() {
    let err = desktop_probe_classify("handshake_ok".into(), None).unwrap_err();
    assert!(err.contains("version required"));
}

#[test]
fn classify_not_reachable_maps_to_unreachable() {
    let r = desktop_probe_classify("not_reachable".into(), None).unwrap();
    assert_eq!(r.kind, "unreachable");
}

#[test]
fn classify_binary_missing_maps_to_not_installed() {
    let r = desktop_probe_classify("binary_missing".into(), None).unwrap();
    assert_eq!(r.kind, "not_installed");
}

#[test]
fn classify_unknown_outcome_errors() {
    let err = desktop_probe_classify("frobnicate".into(), None).unwrap_err();
    assert!(err.contains("unknown probe outcome"));
}

#[test]
fn summary_counts_each_bucket() {
    let mk = |id: &str, kind: &str, version: Option<&str>, min: Option<&str>| {
        ServerProbeResultDto {
            server_id: id.into(),
            probe: DesktopDaemonProbeDto {
                kind: kind.into(),
                version: version.map(str::to_string),
                min_version: min.map(str::to_string),
            },
        }
    };
    let results = vec![
        mk("a", "available", Some("0.71.2"), None),
        mk("b", "available", Some("0.72.0"), None),
        mk("c", "not_installed", None, None),
        mk("d", "unreachable", None, None),
        mk("e", "outdated", Some("0.70.0"), Some("0.71.2")),
        mk("f", "protocol_error", None, None),
    ];
    let s = desktop_probe_summary(results).unwrap();
    assert_eq!(s.total, 6);
    assert_eq!(s.available, 2);
    assert_eq!(s.not_installed, 1);
    assert_eq!(s.unreachable, 1);
    assert_eq!(s.outdated, 1);
    assert_eq!(s.protocol_error, 1);
    assert!(s.any_available);
}

#[test]
fn summary_empty_input() {
    let s = desktop_probe_summary(vec![]).unwrap();
    assert_eq!(s.total, 0);
    assert!(!s.any_available);
}

#[test]
fn min_version_constant_exposed() {
    let v = desktop_probe_min_version();
    assert!(v.starts_with("0.71"));
}
