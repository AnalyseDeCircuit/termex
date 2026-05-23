/// Mobile-only Team Collaboration APIs.
///
/// Supplements the existing `team.rs` FRB module with functions that are
/// specific to mobile — QR invite generation, invite URL parsing, network
/// reachability, and local storage accounting.
///
/// All functions are stubs:  Git / crypto business logic lives in
/// `crates/termex-core/src/team/`; these wrappers will be wired once the
/// iOS/Android cross-compilation chain is validated (v0.58.0 Plan A gate).

// ─── DTOs ────────────────────────────────────────────────────────────────────

/// Parsed content of a `termex-team://join?…` invite URL.
#[derive(Debug, Clone)]
pub struct InviteInfo {
    /// The Git repository URL the invitee should clone.
    pub repo_url: String,
    /// Short-lived token used to authenticate the clone request.
    pub token: String,
    /// Human-readable team name (for display in the join-team sheet).
    pub team_name: String,
    /// ISO 8601 expiry timestamp.
    pub expires_at: String,
}

// ─── Functions ────────────────────────────────────────────────────────────────

/// Generates a QR-code-ready `termex-team://join?…` invite URL and returns it
/// as a UTF-8 string.
///
/// The QR rendering is done on the Dart side via `qr_flutter`; Rust only
/// generates the URL so the crypto token is produced in the trusted boundary.
/// Returns `Err(_)` if `team_id` is unknown or the caller lacks admin rights.
pub fn generate_invite_url(team_id: String, expires_in_hours: u32) -> Result<String, String> {
    let _ = expires_in_hours;
    Ok(format!(
        "termex-team://join?repo=https://example.com/{team_id}&token=STUB_TOKEN&team=Team&expires_at=2099-01-01T00:00:00Z"
    ))
}

/// Parses a raw `termex-team://join?…` string (from a QR scan or clipboard
/// paste) and returns structured invite data.
///
/// Returns `Err(_)` when the scheme is wrong, a required parameter is missing,
/// or the token is expired.
pub fn parse_invite_url(qr_content: String) -> Result<InviteInfo, String> {
    if !qr_content.starts_with("termex-team://join") {
        return Err("invalid invite URL: expected termex-team://join scheme".to_string());
    }
    Ok(InviteInfo {
        repo_url: "https://example.com/stub-repo".to_string(),
        token: "STUB_TOKEN".to_string(),
        team_name: "Team".to_string(),
        expires_at: "2099-01-01T00:00:00Z".to_string(),
    })
}

/// Returns true if the team's Git remote is currently reachable.
///
/// Used to decide whether to enter offline mode.  Times out after 5 seconds
/// (callers should add their own `Future.timeout` on the Dart side).
pub async fn check_team_repo_reachable(team_id: String) -> bool {
    let _ = team_id;
    // Stub: assume reachable until the network layer is wired.
    true
}

/// Returns the on-disk size of the team's local Git clone in kilobytes.
///
/// Used to warn users when the repository exceeds the recommended 50 MB limit.
/// Returns `Err(_)` if the team has never been cloned locally.
pub fn get_team_storage_size(team_id: String) -> Result<u64, String> {
    let _ = team_id;
    Ok(0)
}
