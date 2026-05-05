use std::time::Duration;
use tokio::process::Command;
use tokio::time::timeout;

const CLI_TIMEOUT: Duration = Duration::from_secs(30);

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SsmInstance {
    pub instance_id: String,
    pub name: String,
    pub platform: String,
    pub ip_address: Option<String>,
    pub agent_version: String,
    pub ping_status: String,
}

async fn run_aws(args: &[&str]) -> Result<String, String> {
    let output = timeout(
        CLI_TIMEOUT,
        Command::new("aws").args(args).output(),
    )
    .await
    .map_err(|_| format!("aws cli timed out after {}s", CLI_TIMEOUT.as_secs()))?
    .map_err(|e| format!("aws cli not found: {}", e))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(stderr.trim().to_string());
    }

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

pub async fn list_profiles() -> Result<Vec<String>, String> {
    let output = run_aws(&["configure", "list-profiles"]).await?;
    Ok(output
        .lines()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect())
}

pub fn parse_instances(json_str: &str) -> Result<Vec<SsmInstance>, String> {
    let doc: serde_json::Value =
        serde_json::from_str(json_str).map_err(|e| format!("Invalid JSON: {}", e))?;

    let items = doc
        .get("InstanceInformationList")
        .and_then(|v| v.as_array())
        .ok_or("Missing 'InstanceInformationList'")?;

    let mut result = Vec::with_capacity(items.len());
    for item in items {
        let instance_id = item
            .get("InstanceId")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let name = item
            .get("ComputerName")
            .or_else(|| item.get("Name"))
            .and_then(|v| v.as_str())
            .unwrap_or(&instance_id)
            .to_string();

        let platform = item
            .get("PlatformType")
            .and_then(|v| v.as_str())
            .unwrap_or("Linux")
            .to_string();

        let ip_address = item
            .get("IPAddress")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());

        let agent_version = item
            .get("AgentVersion")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let ping_status = item
            .get("PingStatus")
            .and_then(|v| v.as_str())
            .unwrap_or("ConnectionLost")
            .to_string();

        result.push(SsmInstance {
            instance_id,
            name,
            platform,
            ip_address,
            agent_version,
            ping_status,
        });
    }

    Ok(result)
}

pub async fn list_instances(
    profile: Option<&str>,
    region: Option<&str>,
) -> Result<Vec<SsmInstance>, String> {
    let mut args = vec![
        "ssm",
        "describe-instance-information",
        "--output",
        "json",
    ];
    let profile_flag;
    if let Some(p) = profile {
        profile_flag = p.to_string();
        args.push("--profile");
        args.push(&profile_flag);
    }
    let region_flag;
    if let Some(r) = region {
        region_flag = r.to_string();
        args.push("--region");
        args.push(&region_flag);
    }

    let output = run_aws(&args).await?;
    parse_instances(&output)
}
