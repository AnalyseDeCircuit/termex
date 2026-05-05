use tokio::process::Command;

#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolStatus {
    pub name: String,
    pub available: bool,
    pub version: Option<String>,
    pub path: Option<String>,
}

async fn detect_tool(name: &str, version_args: &[&str]) -> ToolStatus {
    let path = match Command::new("which").arg(name).output().await {
        Ok(out) if out.status.success() => {
            Some(String::from_utf8_lossy(&out.stdout).trim().to_string())
        }
        _ => None,
    };

    let version = if path.is_some() {
        match Command::new(name).args(version_args).output().await {
            Ok(out) if out.status.success() => {
                let raw = String::from_utf8_lossy(&out.stdout);
                Some(raw.trim().to_string())
            }
            Ok(out) => {
                let raw = String::from_utf8_lossy(&out.stderr);
                Some(raw.trim().to_string())
            }
            _ => None,
        }
    } else {
        None
    };

    ToolStatus {
        name: name.to_string(),
        available: path.is_some(),
        version,
        path,
    }
}

pub async fn detect_kubectl() -> ToolStatus {
    detect_tool("kubectl", &["version", "--client", "--short"]).await
}

pub async fn detect_aws_cli() -> ToolStatus {
    detect_tool("aws", &["--version"]).await
}

pub async fn detect_ssm_plugin() -> ToolStatus {
    detect_tool("session-manager-plugin", &["--version"]).await
}

pub async fn detect_all() -> Vec<ToolStatus> {
    let (kubectl, aws, ssm) =
        tokio::join!(detect_kubectl(), detect_aws_cli(), detect_ssm_plugin());
    vec![kubectl, aws, ssm]
}
