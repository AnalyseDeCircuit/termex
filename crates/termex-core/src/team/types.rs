use std::collections::HashMap;
use serde::{Deserialize, Serialize};

// ── Capability-based permission model (v2) ──

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Capability {
    ServerConnect,
    ServerCreate,
    ServerEdit,
    ServerDelete,
    ServerViewCredentials,
    SnippetCreate,
    SnippetEdit,
    SnippetDelete,
    SnippetExecute,
    TeamInvite,
    TeamRemove,
    TeamRoleAssign,
    TeamSettingsEdit,
    SyncPush,
    SyncPull,
    AuditView,
    AuditExport,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TeamRole {
    pub display_name: String,
    pub capabilities: Vec<Capability>,
}

pub fn default_preset_roles() -> HashMap<String, TeamRole> {
    let mut roles = HashMap::new();
    roles.insert("admin".to_string(), TeamRole {
        display_name: "Admin".to_string(),
        capabilities: vec![
            Capability::ServerConnect, Capability::ServerCreate, Capability::ServerEdit,
            Capability::ServerDelete, Capability::ServerViewCredentials,
            Capability::SnippetCreate, Capability::SnippetEdit, Capability::SnippetDelete,
            Capability::SnippetExecute,
            Capability::TeamInvite, Capability::TeamRemove, Capability::TeamRoleAssign,
            Capability::TeamSettingsEdit,
            Capability::SyncPush, Capability::SyncPull,
            Capability::AuditView, Capability::AuditExport,
        ],
    });
    roles.insert("ops".to_string(), TeamRole {
        display_name: "Ops".to_string(),
        capabilities: vec![
            Capability::ServerConnect, Capability::ServerCreate, Capability::ServerEdit,
            Capability::ServerViewCredentials,
            Capability::SnippetCreate, Capability::SnippetEdit, Capability::SnippetExecute,
            Capability::SyncPush, Capability::SyncPull,
            Capability::AuditView,
        ],
    });
    roles.insert("developer".to_string(), TeamRole {
        display_name: "Developer".to_string(),
        capabilities: vec![
            Capability::ServerConnect,
            Capability::SnippetExecute,
            Capability::SyncPull,
        ],
    });
    roles.insert("viewer".to_string(), TeamRole {
        display_name: "Viewer".to_string(),
        capabilities: vec![
            Capability::SyncPull,
            Capability::AuditView,
        ],
    });
    roles
}

/// Per-group permission overrides for a member.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct RoleOverride {
    #[serde(default)]
    pub groups: HashMap<String, Vec<Capability>>,
}

/// Team metadata stored in team.json at the repo root.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TeamJson {
    pub version: u32,
    pub name: String,
    /// Hex-encoded salt for key derivation.
    #[serde(rename = "_salt")]
    pub salt: String,
    /// Base64-encoded verification token (encrypted "TERMEX_TEAM_VERIFY").
    #[serde(rename = "_verify")]
    pub verify: String,
    pub members: Vec<TeamMemberEntry>,
    #[serde(default)]
    pub settings: TeamSettings,
    #[serde(default)]
    pub roles: HashMap<String, TeamRole>,
    #[serde(default)]
    pub role_overrides: HashMap<String, RoleOverride>,
}

/// A member entry in team.json.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TeamMemberEntry {
    pub username: String,
    pub role: String,
    pub joined_at: String,
    pub device_id: String,
}

/// Team-level settings in team.json.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct TeamSettings {
    pub allow_member_push: bool,
    pub require_admin_approve: bool,
    pub password_rotated_at: Option<String>,
    pub audit_retention_days: Option<u32>,
}

impl Default for TeamSettings {
    fn default() -> Self {
        Self {
            allow_member_push: true,
            require_admin_approve: false,
            password_rotated_at: None,
            audit_retention_days: None,
        }
    }
}

/// Server configuration shared via Git repo (servers/{id}.json).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedServerConfig {
    pub id: String,
    pub name: String,
    pub host: String,
    pub port: u16,
    pub username: String,
    pub auth_type: String,
    /// AES-256-GCM encrypted password (base64), or null.
    pub password_enc: Option<String>,
    /// AES-256-GCM encrypted passphrase (base64), or null.
    pub passphrase_enc: Option<String>,
    pub group_id: Option<String>,
    #[serde(default)]
    pub tags: String,
    pub startup_cmd: Option<String>,
    #[serde(default = "default_encoding")]
    pub encoding: String,
    #[serde(default)]
    pub auto_record: bool,
    pub shared_by: String,
    pub shared_at: String,
    pub updated_at: String,
}

fn default_encoding() -> String {
    "UTF-8".to_string()
}

/// Snippet shared via Git repo (snippets/{id}.json).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedSnippet {
    pub id: String,
    pub title: String,
    pub command: String,
    pub description: Option<String>,
    #[serde(default)]
    pub tags: Vec<String>,
    pub folder_id: Option<String>,
    pub shared_by: String,
    pub shared_at: String,
    pub updated_at: String,
}

/// Snippet folder list (snippets/folders.json).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedFolders {
    pub folders: Vec<SharedFolder>,
}

/// A snippet folder entry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedFolder {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub sort_order: i32,
}

/// Group hierarchy (groups/groups.json).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedGroups {
    pub groups: Vec<SharedGroup>,
}

/// A server group entry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedGroup {
    pub id: String,
    pub name: String,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub parent_id: Option<String>,
    #[serde(default)]
    pub sort_order: i32,
}

/// A proxy configuration shared via Git repo (proxies/{id}.json).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedProxy {
    pub id: String,
    pub name: String,
    pub proxy_type: String,
    pub host: String,
    pub port: u16,
    /// AES-256-GCM encrypted username (base64), or null.
    pub username_enc: Option<String>,
    /// AES-256-GCM encrypted password (base64), or null.
    pub password_enc: Option<String>,
    #[serde(default)]
    pub tls_enabled: bool,
    #[serde(default)]
    pub tls_verify: bool,
    pub ca_cert_path: Option<String>,
    pub client_cert_path: Option<String>,
    pub client_key_path: Option<String>,
    pub command: Option<String>,
    pub shared_by: String,
    pub shared_at: String,
    pub updated_at: String,
}

/// A cloud favorite shared via Git repo (cloud_favorites/{id}.json).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedCloudFavorite {
    pub id: String,
    pub name: String,
    /// "kube" or "ssm".
    pub resource_type: String,
    pub context_or_profile: String,
    pub namespace: Option<String>,
    pub region: Option<String>,
    pub shared_by: String,
    pub shared_at: String,
    pub updated_at: String,
}

/// Recording metadata shared via Git repo (recordings/{id}.json).
/// Only metadata is synced — the actual .cast file stays local.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedRecording {
    pub id: String,
    pub server_id: String,
    pub server_name: String,
    pub file_size: i64,
    pub duration_ms: i64,
    pub cols: u32,
    pub rows: u32,
    pub event_count: i64,
    pub summary: Option<String>,
    #[serde(default)]
    pub auto_recorded: bool,
    pub started_at: String,
    pub ended_at: Option<String>,
    pub shared_by: String,
    pub shared_at: String,
    pub updated_at: String,
}

// ── Conflict types ──

/// A detected conflict between local and remote versions.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConflictItem {
    pub entity_type: String,
    pub entity_id: String,
    pub entity_name: String,
    pub local_value: serde_json::Value,
    pub remote_value: serde_json::Value,
    pub conflicting_fields: Vec<String>,
    pub local_modified_by: String,
    pub remote_modified_by: String,
    pub local_modified_at: String,
    pub remote_modified_at: String,
}

/// Strategy for resolving a conflict.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ConflictStrategy {
    KeepLocal,
    UseRemote,
    Skip,
}

/// A single conflict resolution.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConflictResolution {
    pub entity_type: String,
    pub entity_id: String,
    pub strategy: ConflictStrategy,
}

// ── Tauri command return types ──

/// Returned by team_create / team_join.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TeamInfo {
    pub name: String,
    pub repo_url: String,
    pub role: String,
    pub member_count: usize,
    pub created_at: String,
}

/// Returned by team_get_status.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TeamStatus {
    pub joined: bool,
    pub name: Option<String>,
    pub role: Option<String>,
    pub member_count: usize,
    pub last_sync: Option<String>,
    pub has_pending_changes: bool,
    pub repo_url: Option<String>,
    /// True when joined but team key could not be restored from keychain.
    /// Frontend should proactively show the passphrase dialog.
    pub needs_passphrase: bool,
}

/// Returned by team_sync.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TeamSyncResult {
    pub imported: usize,
    pub exported: usize,
    pub conflicts: Vec<ConflictItem>,
    pub deleted_remote: usize,
}

/// Git authentication configuration from frontend.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GitAuthConfig {
    pub auth_type: String,
    pub ssh_key_path: Option<String>,
    pub ssh_passphrase: Option<String>,
    pub token: Option<String>,
    pub username: Option<String>,
    pub password: Option<String>,
}
