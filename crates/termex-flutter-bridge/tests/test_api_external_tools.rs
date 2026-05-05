//! Tests for external-tool detection (v0.46 spec §12.5).
//!
//! These tests do not assume any particular tool is installed on the host
//! machine; they only verify that the probe API returns a structured result
//! and that `found` correlates with a non-empty `version` string.

use termex_flutter_bridge::api::external_tools::*;

#[test]
fn test_check_kubectl_returns_structured_status() {
    let s = external_tool_check_kubectl();
    assert_eq!(s.name, "kubectl");
    // Install URL must always be populated.
    assert!(s.install_url.starts_with("https://"));
    // found ⇔ version is non-empty (up to detection timing quirks).
    if s.found {
        assert!(!s.version.is_empty());
    }
}

#[test]
fn test_check_aws_returns_structured_status() {
    let s = external_tool_check_aws();
    assert_eq!(s.name, "aws");
    assert!(s.install_url.contains("aws.amazon.com"));
}

#[test]
fn test_check_session_manager_plugin_returns_structured_status() {
    let s = external_tool_check_session_manager_plugin();
    assert_eq!(s.name, "session-manager-plugin");
    assert!(s.install_url.contains("session-manager"));
}

#[test]
fn test_check_all_probes_three_tools() {
    let all = external_tool_check_all();
    assert_eq!(all.len(), 3);
    let names: Vec<&str> = all.iter().map(|s| s.name.as_str()).collect();
    assert!(names.contains(&"kubectl"));
    assert!(names.contains(&"aws"));
    assert!(names.contains(&"session-manager-plugin"));
}
