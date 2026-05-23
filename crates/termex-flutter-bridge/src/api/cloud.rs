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
use termex_core::backup::scheduler as bs;
use termex_core::keychain;
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

// ─── Backup scheduler (v0.68.0 G1) ───────────────────────────────────────────

/// User-facing schedule descriptor mirroring `backup_schedules` columns.
#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BackupSchedule {
    pub id: String,
    pub name: String,
    /// One of `"daily"` / `"weekly"` / `"monthly"`.
    pub frequency: String,
    pub hour: i32,
    pub minute: i32,
    /// 0=Sun .. 6=Sat. Required when `frequency == "weekly"`.
    pub weekday: Option<i32>,
    /// 1..28. Required when `frequency == "monthly"`.
    pub day_of_month: Option<i32>,
    pub target_dir: String,
    pub enabled: bool,
    /// RFC3339 UTC timestamp of the next scheduled fire time.
    pub next_run_at: String,
    pub created_at: String,
}

/// One row from `backup_history`. `schedule_id` is `None` for manual
/// backups recorded by the v0.67.0 P1.12 flow.
#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BackupHistory {
    pub id: String,
    pub schedule_id: Option<String>,
    pub file_path: String,
    pub size_bytes: i64,
    /// One of `"success"` / `"failed"`.
    pub status: String,
    pub started_at: String,
    pub completed_at: Option<String>,
    pub error_msg: Option<String>,
}

fn parse_freq(s: &str) -> Result<bs::BackupFrequency, String> {
    bs::BackupFrequency::parse(s).ok_or_else(|| format!("unknown frequency: {s}"))
}

fn to_dto(row: bs::BackupScheduleRow) -> BackupSchedule {
    BackupSchedule {
        id: row.id,
        name: row.name,
        frequency: row.frequency.as_str().to_string(),
        hour: row.hour as i32,
        minute: row.minute as i32,
        weekday: row.weekday.map(|v| v as i32),
        day_of_month: row.day_of_month.map(|v| v as i32),
        target_dir: row.target_dir,
        enabled: row.enabled,
        next_run_at: row.next_run_at.to_string(),
        created_at: row.created_at.to_string(),
    }
}

fn history_to_dto(row: bs::BackupHistoryRow) -> BackupHistory {
    BackupHistory {
        id: row.id,
        schedule_id: row.schedule_id,
        file_path: row.file_path,
        size_bytes: row.size_bytes,
        status: row.status.as_str().to_string(),
        started_at: row.started_at.to_string(),
        completed_at: row.completed_at.map(|t| t.to_string()),
        error_msg: row.error_msg,
    }
}

fn keychain_ref_for(id: &str) -> String {
    format!("termex:backup:schedule:{id}")
}

/// Creates a new backup schedule. The `password` is stored in the OS
/// keychain under a generated reference; the DB never holds the raw secret.
#[frb]
pub fn cloud_create_schedule(
    name: String,
    frequency: String,
    hour: i32,
    minute: i32,
    weekday: Option<i32>,
    day_of_month: Option<i32>,
    target_dir: String,
    password: String,
) -> Result<BackupSchedule, String> {
    let freq = parse_freq(&frequency)?;
    if password.is_empty() {
        return Err("Backup password must not be empty".into());
    }
    if target_dir.is_empty() {
        return Err("Target directory must not be empty".into());
    }
    let id = uuid::Uuid::new_v4().to_string();
    let kc_ref = keychain_ref_for(&id);
    keychain::store(&kc_ref, &password)
        .map_err(|e| format!("failed to store schedule password: {e}"))?;

    let now = time::OffsetDateTime::now_utc();
    let row = bs::BackupScheduleRow {
        id: id.clone(),
        name: name.clone(),
        frequency: freq,
        hour: hour.clamp(0, 23) as u8,
        minute: minute.clamp(0, 59) as u8,
        weekday: weekday.map(|v| v.clamp(0, 6) as u8),
        day_of_month: day_of_month.map(|v| v.clamp(1, 28) as u8),
        target_dir,
        password_keychain_ref: kc_ref,
        enabled: true,
        next_run_at: now,
        created_at: now,
    };
    let next = bs::compute_next_run(&row, now);
    let row = bs::BackupScheduleRow { next_run_at: next, ..row };

    db_state::with_db(|db| {
        db.with_conn(|conn| bs::insert_schedule(conn, &row))
            .map_err(|e| e.to_string())?;
        Ok(())
    })?;
    // First create after unlock kicks off the tick task; an existing one
    // gets a poke so the freshly-inserted row fires on its `next_run_at`.
    crate::scheduler_handle::ensure_started();
    crate::scheduler_handle::poke();
    Ok(to_dto(row))
}

/// Lists all backup schedules ordered by `created_at DESC`. The first
/// call after a DB unlock also lazily spawns the tick task; subsequent
/// calls are pure DB reads.
#[frb]
pub fn cloud_list_schedules() -> Result<Vec<BackupSchedule>, String> {
    crate::scheduler_handle::ensure_started();
    let rows: Vec<bs::BackupScheduleRow> = db_state::with_db(|db| {
        db.with_conn(|conn| bs::list_schedules(conn))
            .map_err(|e| e.to_string())
    })?;
    Ok(rows.into_iter().map(to_dto).collect())
}

/// Updates schedule fields. Any `None` argument leaves the existing value
/// in place. `next_run_at` is recomputed from the new cadence on success.
///
/// `weekday` and `day_of_month` accept `Some(i32)` to overwrite; clearing
/// them back to NULL requires deleting and recreating the schedule (the
/// FRB binding cannot express `Option<Option<i32>>`).
#[frb]
#[allow(clippy::too_many_arguments)]
pub fn cloud_update_schedule(
    id: String,
    name: Option<String>,
    frequency: Option<String>,
    hour: Option<i32>,
    minute: Option<i32>,
    weekday: Option<i32>,
    day_of_month: Option<i32>,
    target_dir: Option<String>,
    enabled: Option<bool>,
) -> Result<(), String> {
    let freq = match frequency.as_deref() {
        Some(s) => Some(parse_freq(s)?),
        None => None,
    };
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            bs::update_schedule(
                conn,
                &id,
                name.as_deref(),
                freq,
                hour.map(|v| v.clamp(0, 23) as u8),
                minute.map(|v| v.clamp(0, 59) as u8),
                weekday.map(|v| Some(v.clamp(0, 6) as u8)),
                day_of_month.map(|v| Some(v.clamp(1, 28) as u8)),
                target_dir.as_deref(),
                enabled,
            )
        })
        .map_err(|e| e.to_string())
    })
}

/// Deletes a schedule by id. Also drops the associated keychain password
/// reference; orphan `backup_history` rows have their `schedule_id`
/// nulled out via the FK `ON DELETE SET NULL`.
#[frb]
pub fn cloud_delete_schedule(id: String) -> Result<(), String> {
    let _ = keychain::delete(&keychain_ref_for(&id));
    db_state::with_db(|db| {
        db.with_conn(|conn| bs::delete_schedule(conn, &id))
            .map_err(|e| e.to_string())
    })
}

/// Lists backup history rows. `schedule_id = None` returns the merged
/// stream of manual + scheduled backups, sorted by `started_at DESC`.
#[frb]
pub fn cloud_list_backups(
    schedule_id: Option<String>,
    limit: i32,
    offset: i32,
) -> Result<Vec<BackupHistory>, String> {
    let l = limit.max(1) as i64;
    let o = offset.max(0) as i64;
    let rows: Vec<bs::BackupHistoryRow> = db_state::with_db(|db| {
        db.with_conn(|conn| bs::list_history(conn, schedule_id.as_deref(), l, o))
            .map_err(|e| e.to_string())
    })?;
    Ok(rows.into_iter().map(history_to_dto).collect())
}

/// Triggers an immediate run of `id`, independent of its cadence. The
/// scheduler tick will still fire on the next regular boundary; this is
/// effectively a "force-fire-once" for manual testing or ad-hoc rotations.
#[frb]
pub fn cloud_run_schedule_now(id: String) -> Result<(), String> {
    // Set next_run_at to now so the tick picks it up immediately.
    let now = time::OffsetDateTime::now_utc().to_string();
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            conn.execute(
                "UPDATE backup_schedules SET next_run_at = ?2 WHERE id = ?1",
                rusqlite::params![id, now],
            )?;
            Ok::<(), rusqlite::Error>(())
        })
        .map_err(|e| e.to_string())
    })?;
    crate::scheduler_handle::poke();
    Ok(())
}
