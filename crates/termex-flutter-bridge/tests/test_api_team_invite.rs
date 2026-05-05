//! Tests for the v0.46 team invite JWT payload (§5.2).

use termex_flutter_bridge::api::team::*;

#[test]
fn test_invite_generate_contains_dot_separator() {
    let invite = team_invite_generate(TeamRole::Member, 24).unwrap();
    assert!(invite.code.contains('.'), "code must be base64.sig format");
}

#[test]
fn test_invite_decode_roundtrip() {
    let invite = team_invite_generate(TeamRole::Admin, 48).unwrap();
    let payload = team_invite_decode(invite.code).unwrap();
    assert_eq!(payload.role, TeamRole::Admin);
    assert!(!payload.team_id.is_empty());
    assert!(!payload.nonce.is_empty());
    assert!(!payload.exp.is_empty());
}

#[test]
fn test_invite_decode_rejects_malformed_code() {
    let err = team_invite_decode("not-a-valid-code".into()).unwrap_err();
    assert!(err.contains("signature") || err.contains("malformed"));
}

#[test]
fn test_invite_decode_rejects_bad_base64() {
    let err = team_invite_decode("!@#$%.abc".into()).unwrap_err();
    assert!(err.contains("malformed"));
}

#[test]
fn test_invite_exp_is_rfc3339_and_in_future() {
    let invite = team_invite_generate(TeamRole::Viewer, 1).unwrap();
    let parsed = chrono::DateTime::parse_from_rfc3339(&invite.expires_at).unwrap();
    assert!(parsed > chrono::Utc::now());
}
