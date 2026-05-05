/// Audit event catalogue — the full list of event types that can appear in the
/// `audit_log` table per the v0.46 spec §4.9.5.
///
/// Every event is a dot-joined `prefix.action` string (e.g. `ssh.connect`).
/// Detail strings are redacted before being passed to `audit_append`.
use flutter_rust_bridge::frb;

/// Event prefixes grouped by subsystem (§4.9.5 of v0.46 spec).
pub const PREFIX_APP: &str = "app";
pub const PREFIX_SERVER: &str = "server";
pub const PREFIX_SSH: &str = "ssh";
pub const PREFIX_SFTP: &str = "sftp";
pub const PREFIX_AI: &str = "ai";
pub const PREFIX_LOCAL_AI: &str = "local_ai";
pub const PREFIX_TEAM: &str = "team";
pub const PREFIX_CLOUD: &str = "cloud";
pub const PREFIX_SNIPPET: &str = "snippet";
pub const PREFIX_CONFIG: &str = "config";
pub const PREFIX_KEYBINDING: &str = "keybinding";

/// The complete catalogue of known event types.
pub const KNOWN_EVENTS: &[&str] = &[
    // app
    "app.start", "app.unlock", "app.lock", "app.shutdown",
    // server
    "server.create", "server.update", "server.delete", "server.import",
    // ssh
    "ssh.connect", "ssh.disconnect", "ssh.auth_fail", "ssh.host_key_change",
    // sftp
    "sftp.upload", "sftp.download", "sftp.delete", "sftp.chmod", "sftp.rename",
    // ai
    "ai.chat", "ai.explain", "ai.diagnose", "ai.nl2cmd",
    // local_ai
    "local_ai.start", "local_ai.stop", "local_ai.download_begin", "local_ai.download_complete",
    // team
    "team.invite_create", "team.invite_accept", "team.sync", "team.role_change", "team.conflict_resolve",
    // cloud
    "cloud.k8s_exec", "cloud.ssm_session", "cloud.kubeconfig_import",
    // snippet
    "snippet.create", "snippet.edit", "snippet.delete", "snippet.execute",
    // config
    "config.export", "config.import", "config.erase_all",
    // keybinding
    "keybinding.customize", "keybinding.reset",
];

/// Returns all known audit-event prefixes as a sorted vector.
#[frb]
pub fn audit_list_prefixes() -> Vec<String> {
    vec![
        PREFIX_APP.into(), PREFIX_SERVER.into(), PREFIX_SSH.into(),
        PREFIX_SFTP.into(), PREFIX_AI.into(), PREFIX_LOCAL_AI.into(),
        PREFIX_TEAM.into(), PREFIX_CLOUD.into(), PREFIX_SNIPPET.into(),
        PREFIX_CONFIG.into(), PREFIX_KEYBINDING.into(),
    ]
}

/// Returns every known `prefix.action` event name.
#[frb]
pub fn audit_list_known_events() -> Vec<String> {
    KNOWN_EVENTS.iter().map(|s| s.to_string()).collect()
}

/// Returns `true` if `event_type` is in the known-events catalogue.
#[frb]
pub fn audit_is_known_event(event_type: String) -> bool {
    KNOWN_EVENTS.contains(&event_type.as_str())
}

/// Redacts sensitive patterns from an audit detail string before persistence.
///
/// Strips any substring that starts with a case-insensitive match of
/// `password:`, `passphrase:`, `token:`, `api_key:`, or `secret:` up to the
/// next whitespace or comma.  Everything else is preserved verbatim.
#[frb]
pub fn audit_redact_detail(detail: String) -> String {
    let markers: &[&str] = &["password:", "passphrase:", "token:", "api_key:", "secret:"];
    let mut out = String::with_capacity(detail.len());
    let lower = detail.to_lowercase();
    let bytes = detail.as_bytes();
    let mut i = 0usize;

    while i < bytes.len() {
        let mut matched_len = None;
        for marker in markers {
            if lower[i..].starts_with(marker) {
                matched_len = Some(marker.len());
                break;
            }
        }
        if let Some(mlen) = matched_len {
            // Copy marker, then replace value with "***".
            out.push_str(&detail[i..i + mlen]);
            i += mlen;
            out.push_str("***");
            // Skip until next whitespace or comma.
            while i < bytes.len() {
                let c = bytes[i] as char;
                if c == ' ' || c == ',' || c == '\t' || c == '\n' || c == ';' {
                    break;
                }
                i += 1;
            }
        } else {
            out.push(detail[i..].chars().next().unwrap());
            i += detail[i..].chars().next().unwrap().len_utf8();
        }
    }
    out
}
