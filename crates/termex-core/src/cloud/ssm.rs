//! DTOs and pure parsers for AWS SSM Session Manager.
//!
//! The async `aws` CLI invocations (list_profiles, list_instances) live
//! in `termex-core-private::cloud::ssm`.

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

/// Parses `aws ssm describe-instance-information --output json` output.
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
