//! DTOs and pure parsers for Kubernetes context / pod listing.
//!
//! The async `kubectl` invocations (list_contexts, list_namespaces,
//! list_pods) live in `termex-core-private::cloud::kube`.

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KubeContext {
    pub name: String,
    pub cluster: String,
    pub user: String,
    pub namespace: Option<String>,
    pub is_current: bool,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PodInfo {
    pub name: String,
    pub namespace: String,
    pub status: String,
    pub ready: String,
    pub restarts: u32,
    pub age: String,
    pub node: String,
    pub containers: Vec<ContainerInfo>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ContainerInfo {
    pub name: String,
    pub image: String,
    pub ready: bool,
    pub restart_count: u32,
    pub state: String,
}

/// Parses `kubectl config view -o json` output into a list of contexts.
///
/// Pure function (no I/O) so it stays in OSS for unit tests and Tauri-side
/// type compatibility.
pub fn parse_contexts(json_str: &str) -> Result<Vec<KubeContext>, String> {
    let doc: serde_json::Value =
        serde_json::from_str(json_str).map_err(|e| format!("Invalid JSON: {}", e))?;

    let current = doc
        .get("current-context")
        .and_then(|v| v.as_str())
        .unwrap_or("");

    let contexts = doc
        .get("contexts")
        .and_then(|v| v.as_array())
        .ok_or("Missing 'contexts' array")?;

    let mut result = Vec::with_capacity(contexts.len());
    for ctx in contexts {
        let name = ctx.get("name").and_then(|v| v.as_str()).unwrap_or("");
        let context_obj = ctx.get("context");
        let cluster = context_obj
            .and_then(|c| c.get("cluster"))
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let user = context_obj
            .and_then(|c| c.get("user"))
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let namespace = context_obj
            .and_then(|c| c.get("namespace"))
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());

        result.push(KubeContext {
            name: name.to_string(),
            cluster: cluster.to_string(),
            user: user.to_string(),
            namespace,
            is_current: name == current,
        });
    }

    Ok(result)
}

/// Parses `kubectl get pods -o json` output into a list of pod summaries.
pub fn parse_pod_list(json_str: &str) -> Result<Vec<PodInfo>, String> {
    let doc: serde_json::Value =
        serde_json::from_str(json_str).map_err(|e| format!("Invalid JSON: {}", e))?;

    let items = doc
        .get("items")
        .and_then(|v| v.as_array())
        .ok_or("Missing 'items' array")?;

    let mut result = Vec::with_capacity(items.len());
    for item in items {
        let metadata = item.get("metadata");
        let name = metadata
            .and_then(|m| m.get("name"))
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        let namespace = metadata
            .and_then(|m| m.get("namespace"))
            .and_then(|v| v.as_str())
            .unwrap_or("default")
            .to_string();

        let status_obj = item.get("status");
        let phase = status_obj
            .and_then(|s| s.get("phase"))
            .and_then(|v| v.as_str())
            .unwrap_or("Unknown")
            .to_string();

        let spec = item.get("spec");
        let node = spec
            .and_then(|s| s.get("nodeName"))
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let container_statuses = status_obj
            .and_then(|s| s.get("containerStatuses"))
            .and_then(|v| v.as_array());

        let spec_containers = spec
            .and_then(|s| s.get("containers"))
            .and_then(|v| v.as_array());

        let mut containers = Vec::new();
        let mut total_restarts: u32 = 0;
        let mut ready_count = 0u32;
        let total_count = spec_containers.map_or(0u32, |c| c.len() as u32);

        if let Some(statuses) = container_statuses {
            for cs in statuses {
                let c_name = cs
                    .get("name")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                let c_ready = cs.get("ready").and_then(|v| v.as_bool()).unwrap_or(false);
                let c_restarts = cs
                    .get("restartCount")
                    .and_then(|v| v.as_u64())
                    .unwrap_or(0) as u32;
                let c_image = cs
                    .get("image")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();

                let c_state = if let Some(state) = cs.get("state") {
                    if state.get("running").is_some() {
                        "running"
                    } else if state.get("waiting").is_some() {
                        "waiting"
                    } else if state.get("terminated").is_some() {
                        "terminated"
                    } else {
                        "unknown"
                    }
                } else {
                    "unknown"
                };

                if c_ready {
                    ready_count += 1;
                }
                total_restarts += c_restarts;

                containers.push(ContainerInfo {
                    name: c_name,
                    image: c_image,
                    ready: c_ready,
                    restart_count: c_restarts,
                    state: c_state.to_string(),
                });
            }
        } else if let Some(specs) = spec_containers {
            for sc in specs {
                containers.push(ContainerInfo {
                    name: sc
                        .get("name")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string(),
                    image: sc
                        .get("image")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string(),
                    ready: false,
                    restart_count: 0,
                    state: "waiting".to_string(),
                });
            }
        }

        let creation = metadata
            .and_then(|m| m.get("creationTimestamp"))
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let age = compute_age(creation);

        result.push(PodInfo {
            name,
            namespace,
            status: phase,
            ready: format!("{}/{}", ready_count, total_count),
            restarts: total_restarts,
            age,
            node,
            containers,
        });
    }

    Ok(result)
}

fn compute_age(creation_timestamp: &str) -> String {
    use std::time::{Duration, SystemTime, UNIX_EPOCH};

    let ts = creation_timestamp.trim().trim_end_matches('Z');
    let parts: Vec<&str> = ts.splitn(2, 'T').collect();
    if parts.len() != 2 {
        return String::new();
    }
    let date_parts: Vec<u64> = parts[0].split('-').filter_map(|s| s.parse().ok()).collect();
    let time_parts: Vec<u64> = parts[1]
        .split(|c: char| !c.is_ascii_digit())
        .filter(|s| !s.is_empty())
        .take(3)
        .filter_map(|s| s.parse().ok())
        .collect();

    if date_parts.len() < 3 || time_parts.len() < 3 {
        return String::new();
    }

    let (year, month, day) = (date_parts[0], date_parts[1], date_parts[2]);
    let (hour, min, sec) = (time_parts[0], time_parts[1], time_parts[2]);

    let days_since_epoch = days_from_civil(year as i64, month as u32, day as u32);
    let created_secs = days_since_epoch as u64 * 86400 + hour * 3600 + min * 60 + sec;

    let now_secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or(Duration::ZERO)
        .as_secs();

    if now_secs < created_secs {
        return String::new();
    }
    let elapsed = now_secs - created_secs;
    let days = elapsed / 86400;
    let hours = elapsed / 3600;
    let minutes = elapsed / 60;

    if days > 0 {
        format!("{}d", days)
    } else if hours > 0 {
        format!("{}h", hours)
    } else {
        format!("{}m", minutes)
    }
}

/// Converts y/m/d to days since Unix epoch (civil date algorithm).
fn days_from_civil(y: i64, m: u32, d: u32) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = (y - era * 400) as u32;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146097 + doe as i64 - 719468
}
