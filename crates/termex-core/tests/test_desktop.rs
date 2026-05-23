//! Integration tests for the desktop daemon-probe classifier.

use termex_core::desktop::probe::{
    classify_probe, probe_batch_summary, version_at_least, DaemonProbe, ProbeOutcome,
    ServerProbeResult, MIN_TERMEXD_VERSION,
};

// ── version_at_least ──────────────────────────────────────────────

#[test]
fn version_equal_passes() {
    assert!(version_at_least("0.71.2", "0.71.2"));
}

#[test]
fn version_higher_patch_passes() {
    assert!(version_at_least("0.71.5", "0.71.2"));
}

#[test]
fn version_higher_minor_passes() {
    assert!(version_at_least("0.72.0", "0.71.2"));
}

#[test]
fn version_higher_major_passes() {
    assert!(version_at_least("1.0.0", "0.71.2"));
}

#[test]
fn version_lower_patch_fails() {
    assert!(!version_at_least("0.71.1", "0.71.2"));
}

#[test]
fn version_lower_minor_fails() {
    assert!(!version_at_least("0.70.99", "0.71.2"));
}

#[test]
fn version_strips_pre_release_suffix() {
    // 0.71.2-dev should compare as 0.71.2 (≥ 0.71.2).
    assert!(version_at_least("0.71.2-dev", "0.71.2"));
    // 0.71.1-rc1 still below 0.71.2.
    assert!(!version_at_least("0.71.1-rc1", "0.71.2"));
}

#[test]
fn version_strips_build_metadata() {
    assert!(version_at_least("0.71.2+sha.abc123", "0.71.2"));
}

#[test]
fn version_malformed_fails_closed() {
    assert!(!version_at_least("not-a-version", "0.71.2"));
    assert!(!version_at_least("0.71", "0.71.2")); // only 2 segments
    assert!(!version_at_least("0.71.2.4", "0.71.2")); // 4 segments
    assert!(!version_at_least("", "0.71.2"));
}

// ── classify_probe ────────────────────────────────────────────────

#[test]
fn classify_handshake_at_min_returns_available() {
    let r = classify_probe(ProbeOutcome::HandshakeOk {
        version: MIN_TERMEXD_VERSION.to_string(),
    });
    assert_eq!(
        r,
        DaemonProbe::Available {
            version: MIN_TERMEXD_VERSION.to_string()
        }
    );
}

#[test]
fn classify_handshake_above_min_returns_available() {
    let r = classify_probe(ProbeOutcome::HandshakeOk {
        version: "0.99.0".into(),
    });
    assert!(matches!(r, DaemonProbe::Available { .. }));
}

#[test]
fn classify_handshake_below_min_returns_outdated() {
    let r = classify_probe(ProbeOutcome::HandshakeOk {
        version: "0.70.0".into(),
    });
    match r {
        DaemonProbe::Outdated { version, min_version } => {
            assert_eq!(version, "0.70.0");
            assert_eq!(min_version, MIN_TERMEXD_VERSION);
        }
        other => panic!("expected Outdated, got {other:?}"),
    }
}

#[test]
fn classify_binary_missing_maps_to_not_installed() {
    let r = classify_probe(ProbeOutcome::BinaryMissing);
    assert_eq!(r, DaemonProbe::NotInstalled);
}

#[test]
fn classify_not_reachable_maps_to_unreachable() {
    let r = classify_probe(ProbeOutcome::NotReachable);
    assert_eq!(r, DaemonProbe::Unreachable);
}

#[test]
fn classify_protocol_error_maps_to_protocol_error() {
    let r = classify_probe(ProbeOutcome::ProtocolError);
    assert_eq!(r, DaemonProbe::ProtocolError);
}

#[test]
fn classify_garbage_version_falls_into_outdated() {
    let r = classify_probe(ProbeOutcome::HandshakeOk {
        version: "🤖".into(),
    });
    assert!(matches!(r, DaemonProbe::Outdated { .. }));
}

// ── DaemonProbe predicates ────────────────────────────────────────

#[test]
fn is_usable_only_for_available() {
    assert!(DaemonProbe::Available { version: "0.71.2".into() }.is_usable());
    assert!(!DaemonProbe::NotInstalled.is_usable());
    assert!(!DaemonProbe::Unreachable.is_usable());
    assert!(!DaemonProbe::Outdated {
        version: "0.70.0".into(),
        min_version: "0.71.2".into(),
    }
    .is_usable());
    assert!(!DaemonProbe::ProtocolError.is_usable());
}

#[test]
fn offers_install_only_for_not_installed() {
    assert!(DaemonProbe::NotInstalled.offers_install());
    assert!(!DaemonProbe::Unreachable.offers_install());
    assert!(!DaemonProbe::Available { version: "0.71.2".into() }.offers_install());
}

#[test]
fn offers_upgrade_only_for_outdated() {
    assert!(DaemonProbe::Outdated {
        version: "0.70.0".into(),
        min_version: "0.71.2".into(),
    }
    .offers_upgrade());
    assert!(!DaemonProbe::NotInstalled.offers_upgrade());
    assert!(!DaemonProbe::Available { version: "0.71.2".into() }.offers_upgrade());
}

// ── ProbeBatchSummary ────────────────────────────────────────────

fn result(server: &str, probe: DaemonProbe) -> ServerProbeResult {
    ServerProbeResult {
        server_id: server.into(),
        probe,
    }
}

#[test]
fn batch_summary_empty_is_default() {
    let s = probe_batch_summary(&[]);
    assert_eq!(s.total, 0);
    assert!(!s.any_available());
}

#[test]
fn batch_summary_counts_each_bucket() {
    let r = vec![
        result("a", DaemonProbe::Available { version: "0.71.2".into() }),
        result("b", DaemonProbe::Available { version: "0.72.0".into() }),
        result("c", DaemonProbe::NotInstalled),
        result("d", DaemonProbe::Unreachable),
        result("e", DaemonProbe::Outdated {
            version: "0.70.0".into(),
            min_version: "0.71.2".into(),
        }),
        result("f", DaemonProbe::ProtocolError),
    ];
    let s = probe_batch_summary(&r);
    assert_eq!(s.total, 6);
    assert_eq!(s.available, 2);
    assert_eq!(s.not_installed, 1);
    assert_eq!(s.unreachable, 1);
    assert_eq!(s.outdated, 1);
    assert_eq!(s.protocol_error, 1);
    assert!(s.any_available());
}

#[test]
fn batch_summary_no_available_when_only_failures() {
    let r = vec![
        result("a", DaemonProbe::NotInstalled),
        result("b", DaemonProbe::Unreachable),
    ];
    let s = probe_batch_summary(&r);
    assert!(!s.any_available());
    assert_eq!(s.not_installed, 1);
    assert_eq!(s.unreachable, 1);
}

// ── serde wire shape ─────────────────────────────────────────────

#[test]
fn daemon_probe_serializes_with_tag_kind() {
    let p = DaemonProbe::Available { version: "0.72.0".into() };
    let json = serde_json::to_value(&p).unwrap();
    assert_eq!(json["kind"], "available");
    assert_eq!(json["version"], "0.72.0");

    let p2 = DaemonProbe::NotInstalled;
    let json2 = serde_json::to_value(&p2).unwrap();
    assert_eq!(json2["kind"], "not_installed");

    let p3 = DaemonProbe::Outdated {
        version: "0.70.0".into(),
        min_version: "0.71.2".into(),
    };
    let json3 = serde_json::to_value(&p3).unwrap();
    assert_eq!(json3["kind"], "outdated");
    assert_eq!(json3["min_version"], "0.71.2");
}

#[test]
fn daemon_probe_round_trips_through_serde() {
    for p in [
        DaemonProbe::Available { version: "0.71.2".into() },
        DaemonProbe::NotInstalled,
        DaemonProbe::Unreachable,
        DaemonProbe::Outdated {
            version: "0.70.0".into(),
            min_version: "0.71.2".into(),
        },
        DaemonProbe::ProtocolError,
    ] {
        let s = serde_json::to_string(&p).unwrap();
        let back: DaemonProbe = serde_json::from_str(&s).unwrap();
        assert_eq!(back, p, "round-trip failed for {p:?}");
    }
}
