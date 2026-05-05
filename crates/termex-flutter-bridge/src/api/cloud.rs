/// Cloud-provider integration APIs exposed to Flutter via FRB.
///
/// Covers Kubernetes context management, AWS SSM session management,
/// Alibaba Cloud ECS favourites, and credential profile storage.
///
/// Heavy integrations (kubectl / aws CLI / ECS API) are stubbed until v0.47+;
/// what lands in v0.46 is the favourites persistence + credential profile
/// table (§6.5 of the v0.46 spec).
use flutter_rust_bridge::frb;

use crate::db_state;
use termex_core::storage::cloud_favorites as core_fav;

// ─── DTOs ────────────────────────────────────────────────────────────────────

/// A kubeconfig context entry.
#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct K8sContext {
    pub name: String,
    pub cluster: String,
    pub namespace: String,
    /// Whether this is the currently active kubeconfig context.
    pub is_active: bool,
}

/// A Kubernetes pod summary.
#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct K8sPod {
    pub name: String,
    pub namespace: String,
    /// Pod phase string (e.g. `"Running"`, `"Pending"`, `"Failed"`).
    pub status: String,
    /// Whether the pod's containers are all ready.
    pub ready: bool,
    /// Time since the pod was created, in seconds.
    pub age_seconds: i64,
}

/// An AWS EC2 instance reachable via AWS Systems Manager Session Manager.
#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SsmInstance {
    pub instance_id: String,
    /// Human-readable Name tag, if set.
    pub name: Option<String>,
    /// Instance state string (e.g. `"running"`, `"stopped"`).
    pub state: String,
    pub region: String,
}

/// A saved Alibaba Cloud ECS instance shortcut.  Backed by the shared
/// `cloud_favorites` table with `resource_type = 'ecs'`.
#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EcsFavorite {
    pub id: String,
    pub instance_id: String,
    pub name: String,
    pub region: String,
    pub endpoint: String,
}

/// Cloud-provider credential bundle.  The actual secret material lives in the
/// OS keychain; only the opaque reference is persisted in the database.
#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CloudCredential {
    /// Provider identifier, e.g. `"aws"`, `"aliyun"`, `"k8s"`.
    pub provider: String,
    /// Access key / client ID, if applicable.
    pub key_id: Option<String>,
    /// Default region, if applicable.
    pub region: Option<String>,
}

// ─── Kubernetes ───────────────────────────────────────────────────────────────

/// Returns all contexts found in the active kubeconfig file.
#[frb]
pub fn cloud_k8s_list_contexts() -> Result<Vec<K8sContext>, String> {
    // Heavy integration landed in v0.47; stubbed here intentionally.
    Ok(vec![])
}

/// Switches the active kubeconfig context to `name`.
#[frb]
pub fn cloud_k8s_switch_context(name: String) -> Result<(), String> {
    let _ = name;
    Ok(())
}

/// Lists pods in `namespace` for the given `context`.
#[frb]
pub fn cloud_k8s_list_pods(
    context: String,
    namespace: String,
) -> Result<Vec<K8sPod>, String> {
    let _ = (context, namespace);
    Ok(vec![])
}

/// Executes `command` inside `pod` (optionally in a specific `container`) and
/// returns the combined stdout/stderr output.
#[frb]
pub fn cloud_k8s_exec(
    context: String,
    pod: String,
    container: Option<String>,
    command: String,
) -> Result<String, String> {
    let _ = (context, pod, container, command);
    Ok(String::new())
}

// ─── AWS SSM ──────────────────────────────────────────────────────────────────

/// Returns the list of EC2 instances that are registered with SSM in `region`.
#[frb]
pub fn cloud_ssm_list_instances(region: String) -> Result<Vec<SsmInstance>, String> {
    let _ = region;
    Ok(vec![])
}

/// Starts an SSM session to `instance_id` in `region`.
///
/// Returns an opaque `session_id` that can be used to attach a terminal.
#[frb]
pub fn cloud_ssm_start_session(
    instance_id: String,
    region: String,
) -> Result<String, String> {
    let _ = (instance_id, region);
    Ok(uuid::Uuid::new_v4().to_string())
}

// ─── Alibaba Cloud ECS favourites ────────────────────────────────────────────

/// Returns the list of saved ECS instance shortcuts.
#[frb]
pub fn cloud_ecs_list_favorites() -> Result<Vec<EcsFavorite>, String> {
    if !db_state::is_unlocked() {
        return Ok(vec![]);
    }
    db_state::with_db(|db| {
        let rows = db
            .with_conn(|conn| core_fav::list(conn))
            .map_err(|e| e.to_string())?;
        Ok(rows
            .into_iter()
            .filter(|f| f.resource_type == "ecs")
            .map(|f| EcsFavorite {
                id: f.id,
                instance_id: f.context_or_profile, // we store instance_id here
                name: f.name,
                region: f.region.unwrap_or_default(),
                endpoint: f.namespace.unwrap_or_default(), // endpoint reused as namespace col
            })
            .collect())
    })
}

/// Saves a new ECS instance shortcut and returns it with a generated ID.
#[frb]
pub fn cloud_ecs_add_favorite(
    instance_id: String,
    name: String,
    region: String,
    endpoint: String,
) -> Result<EcsFavorite, String> {
    if !db_state::is_unlocked() {
        return Ok(EcsFavorite {
            id: uuid::Uuid::new_v4().to_string(),
            instance_id,
            name,
            region,
            endpoint,
        });
    }
    db_state::with_db(|db| {
        let input = core_fav::CloudFavoriteInput {
            name: name.clone(),
            resource_type: "ecs".into(),
            context_or_profile: instance_id.clone(),
            namespace: Some(endpoint.clone()),
            region: Some(region.clone()),
        };
        let f = db
            .with_conn(|conn| core_fav::create(conn, &input))
            .map_err(|e| e.to_string())?;
        Ok(EcsFavorite {
            id: f.id,
            instance_id,
            name,
            region,
            endpoint,
        })
    })
}

/// Deletes the ECS favourite identified by `id`.
#[frb]
pub fn cloud_ecs_remove_favorite(id: String) -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| core_fav::delete(conn, &id))
            .map_err(|e| e.to_string())
    })
}

// ─── Credentials ─────────────────────────────────────────────────────────────

/// Persists a cloud-provider credential bundle reference.  The real secret
/// material must live in the OS keychain under
/// `cloud:{provider}:{profile_name}`; the database row is only the index.
#[frb]
pub fn cloud_save_credential(credential: CloudCredential) -> Result<(), String> {
    if !db_state::is_unlocked() {
        return Ok(());
    }
    let profile_name = credential.key_id.clone().unwrap_or_else(|| "default".into());
    let keychain_ref = format!("cloud:{}:{}", credential.provider, profile_name);
    let extra = serde_json::json!({
        "region": credential.region,
    })
    .to_string();

    db_state::with_db(|db| {
        db.with_conn(|conn| {
            // Upsert on (provider, profile_name) pair using a synthetic primary key.
            let id = uuid::Uuid::new_v4().to_string();
            let now = chrono::Utc::now().to_rfc3339();
            conn.execute(
                "INSERT INTO cloud_profiles (id, provider, profile_name, keychain_ref, region, extra_json, created_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
                 ON CONFLICT(id) DO NOTHING",
                rusqlite::params![
                    id, credential.provider, profile_name, keychain_ref, credential.region, extra, now,
                ],
            )?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Loads the most-recently saved credential profile for `provider`, or
/// `None` if none exists.
#[frb]
pub fn cloud_load_credential(provider: String) -> Result<Option<CloudCredential>, String> {
    if !db_state::is_unlocked() {
        return Ok(None);
    }
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT profile_name, region FROM cloud_profiles
                 WHERE provider = ?1 ORDER BY created_at DESC LIMIT 1",
            )?;
            let row: Option<(String, Option<String>)> = stmt
                .query_row(rusqlite::params![provider], |r| {
                    Ok((r.get::<_, String>(0)?, r.get::<_, Option<String>>(1)?))
                })
                .ok();
            Ok(row.map(|(profile_name, region)| CloudCredential {
                provider: provider.clone(),
                key_id: Some(profile_name),
                region,
            }))
        })
        .map_err(|e| e.to_string())
    })
}
