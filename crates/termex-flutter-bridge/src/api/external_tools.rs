/// External runtime dependency detection (v0.46 spec §12.5).
///
/// Some cloud integrations require system-installed CLIs (kubectl, aws,
/// session-manager-plugin).  We detect their presence via a `--version`
/// probe and return a structured result so the UI can render a friendly
/// "install this tool" banner.
use flutter_rust_bridge::frb;
use std::process::Command;

/// Result of a single external-tool presence probe.
#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExternalToolStatus {
    pub name: String,
    pub found: bool,
    /// Stdout of the version probe (trimmed) when found; empty otherwise.
    pub version: String,
    /// Suggested install URL to show in the UI banner when not found.
    pub install_url: String,
}

fn probe(name: &str, args: &[&str], install_url: &str) -> ExternalToolStatus {
    let output = Command::new(name).args(args).output();
    match output {
        Ok(o) if o.status.success() => {
            let stdout = String::from_utf8_lossy(&o.stdout).trim().to_string();
            let version = if stdout.is_empty() {
                String::from_utf8_lossy(&o.stderr).trim().to_string()
            } else {
                stdout
            };
            // Trim long outputs (e.g. kubectl JSON) to a single line preview.
            let first_line = version.lines().next().unwrap_or("").to_string();
            ExternalToolStatus {
                name: name.into(),
                found: true,
                version: first_line,
                install_url: install_url.into(),
            }
        }
        _ => ExternalToolStatus {
            name: name.into(),
            found: false,
            version: String::new(),
            install_url: install_url.into(),
        },
    }
}

/// Detects `kubectl` (v1.24+ required for client-side namespace flag).
#[frb]
pub fn external_tool_check_kubectl() -> ExternalToolStatus {
    probe(
        "kubectl",
        &["version", "--client", "--output=yaml"],
        "https://kubernetes.io/docs/tasks/tools/",
    )
}

/// Detects the AWS CLI v2.
#[frb]
pub fn external_tool_check_aws() -> ExternalToolStatus {
    probe(
        "aws",
        &["--version"],
        "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html",
    )
}

/// Detects AWS Session Manager plugin (required for SSM `start-session`).
#[frb]
pub fn external_tool_check_session_manager_plugin() -> ExternalToolStatus {
    probe(
        "session-manager-plugin",
        &["--version"],
        "https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html",
    )
}

/// Probes all cloud-related external tools in one call.
#[frb]
pub fn external_tool_check_all() -> Vec<ExternalToolStatus> {
    vec![
        external_tool_check_kubectl(),
        external_tool_check_aws(),
        external_tool_check_session_manager_plugin(),
    ]
}
