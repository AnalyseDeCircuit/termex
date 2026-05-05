/// Plugin management FRB bridge (v0.48 spec §7).
///
/// Wraps `termex_core::plugin::PluginRegistry`.  Because the registry lives in
/// a process-local Mutex (no DB), the API is available even before the master
/// password is entered.  Permission grants are stored in the same Mutex as part
/// of `PluginRuntimeState`.
use std::collections::HashMap;
use std::sync::Mutex;

use once_cell::sync::Lazy;

use termex_core::plugin::manifest::{PluginManifest, PluginPermission};
use termex_core::plugin::registry::{InstalledPlugin, PluginState};

// ─── DTOs ────────────────────────────────────────────────────────────────────

/// Flat DTO for a single installed plugin (FRB-friendly, no nested enums).
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PluginDto {
    pub id: String,
    pub name: String,
    pub version: String,
    pub description: String,
    pub author: Option<String>,
    /// `"enabled"` or `"disabled"`.
    pub state: String,
    /// Serialised permission names, e.g. `["terminal_read", "network"]`.
    pub permissions: Vec<String>,
    pub install_path: String,
    /// Permissions the user has explicitly granted (subset of `permissions`).
    pub granted_permissions: Vec<String>,
}

/// Result of a permission-check operation.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PermissionCheckResult {
    pub plugin_id: String,
    pub permission: String,
    pub granted: bool,
}

// ─── In-process registry ─────────────────────────────────────────────────────

struct PluginRuntimeState {
    plugins: Vec<InstalledPlugin>,
    /// plugin_id → set of granted permission names.
    grants: HashMap<String, Vec<String>>,
    /// Developer mode: allows loading unsigned plugins.
    developer_mode: bool,
}

static PLUGIN_STATE: Lazy<Mutex<PluginRuntimeState>> = Lazy::new(|| {
    Mutex::new(PluginRuntimeState {
        plugins: vec![],
        grants: HashMap::new(),
        developer_mode: false,
    })
});

fn permission_name(p: &PluginPermission) -> &'static str {
    match p {
        PluginPermission::TerminalRead => "terminal_read",
        PluginPermission::TerminalWrite => "terminal_write",
        PluginPermission::ServerInfo => "server_info",
        PluginPermission::Network => "network",
        PluginPermission::Storage => "storage",
        PluginPermission::Clipboard => "clipboard",
        PluginPermission::Notification => "notification",
    }
}

fn to_dto(p: &InstalledPlugin, grants: &HashMap<String, Vec<String>>) -> PluginDto {
    let state_str = match p.state {
        PluginState::Enabled => "enabled",
        PluginState::Disabled => "disabled",
    };
    let perms: Vec<String> = p
        .manifest
        .permissions
        .iter()
        .map(|perm| permission_name(perm).to_string())
        .collect();
    let granted = grants
        .get(&p.manifest.id)
        .cloned()
        .unwrap_or_default();
    PluginDto {
        id: p.manifest.id.clone(),
        name: p.manifest.name.clone(),
        version: p.manifest.version.clone(),
        description: p.manifest.description.clone(),
        author: p.manifest.author.clone(),
        state: state_str.to_string(),
        permissions: perms,
        install_path: p.install_path.clone(),
        granted_permissions: granted,
    }
}

// ─── Public API ───────────────────────────────────────────────────────────────

/// Returns all installed plugins with their current state and granted permissions.
pub fn plugin_list() -> Vec<PluginDto> {
    let st = PLUGIN_STATE.lock().unwrap();
    st.plugins.iter().map(|p| to_dto(p, &st.grants)).collect()
}

/// Registers a plugin from a parsed manifest string (JSON).
///
/// In the real app, `install_path` is the extracted ZIP directory.  Here we
/// accept manifest JSON directly so tests don't need filesystem interaction.
pub fn plugin_register(manifest_json: String, install_path: String) -> Result<PluginDto, String> {
    let manifest: PluginManifest =
        serde_json::from_str(&manifest_json).map_err(|e| e.to_string())?;
    let id = manifest.id.clone();

    let mut st = PLUGIN_STATE.lock().unwrap();
    if st.plugins.iter().any(|p| p.manifest.id == id) {
        return Err(format!("plugin '{id}' is already installed"));
    }

    let plugin = InstalledPlugin {
        manifest,
        state: PluginState::Enabled,
        install_path,
    };
    let dto = to_dto(&plugin, &st.grants);
    st.plugins.push(plugin);
    Ok(dto)
}

/// Uninstalls the plugin with the given ID.
pub fn plugin_uninstall(plugin_id: String) -> Result<(), String> {
    let mut st = PLUGIN_STATE.lock().unwrap();
    let pos = st
        .plugins
        .iter()
        .position(|p| p.manifest.id == plugin_id)
        .ok_or_else(|| format!("plugin '{plugin_id}' not found"))?;
    st.plugins.remove(pos);
    st.grants.remove(&plugin_id);
    Ok(())
}

/// Enables a previously-disabled plugin.
pub fn plugin_enable(plugin_id: String) -> Result<(), String> {
    let mut st = PLUGIN_STATE.lock().unwrap();
    let p = st
        .plugins
        .iter_mut()
        .find(|p| p.manifest.id == plugin_id)
        .ok_or_else(|| format!("plugin '{plugin_id}' not found"))?;
    p.state = PluginState::Enabled;
    Ok(())
}

/// Disables a plugin without uninstalling it.
pub fn plugin_disable(plugin_id: String) -> Result<(), String> {
    let mut st = PLUGIN_STATE.lock().unwrap();
    let p = st
        .plugins
        .iter_mut()
        .find(|p| p.manifest.id == plugin_id)
        .ok_or_else(|| format!("plugin '{plugin_id}' not found"))?;
    p.state = PluginState::Disabled;
    Ok(())
}

/// Grants a permission to a plugin.  Returns an error when the permission is
/// not declared in the plugin's manifest.
pub fn plugin_grant_permission(plugin_id: String, permission: String) -> Result<(), String> {
    let mut st = PLUGIN_STATE.lock().unwrap();
    let p = st
        .plugins
        .iter()
        .find(|p| p.manifest.id == plugin_id)
        .ok_or_else(|| format!("plugin '{plugin_id}' not found"))?;

    let declared: Vec<&str> = p.manifest.permissions.iter().map(permission_name).collect();
    if !declared.contains(&permission.as_str()) {
        return Err(format!(
            "permission '{permission}' not declared in plugin manifest"
        ));
    }

    let entry = st.grants.entry(plugin_id).or_default();
    if !entry.contains(&permission) {
        entry.push(permission);
    }
    Ok(())
}

/// Revokes a previously-granted permission.
pub fn plugin_revoke_permission(plugin_id: String, permission: String) -> Result<(), String> {
    let mut st = PLUGIN_STATE.lock().unwrap();
    if let Some(grants) = st.grants.get_mut(&plugin_id) {
        grants.retain(|p| p != &permission);
    }
    Ok(())
}

/// Returns whether a specific permission has been granted to a plugin.
pub fn plugin_check_permission(plugin_id: String, permission: String) -> PermissionCheckResult {
    let st = PLUGIN_STATE.lock().unwrap();
    let granted = st
        .grants
        .get(&plugin_id)
        .map(|g| g.contains(&permission))
        .unwrap_or(false);
    PermissionCheckResult {
        plugin_id,
        permission,
        granted,
    }
}

/// Toggles developer mode (allows loading unsigned / unverified plugins).
pub fn plugin_set_developer_mode(enabled: bool) {
    PLUGIN_STATE.lock().unwrap().developer_mode = enabled;
}

/// Returns whether developer mode is currently active.
pub fn plugin_developer_mode() -> bool {
    PLUGIN_STATE.lock().unwrap().developer_mode
}

/// Removes all plugins and resets grants — used in tests.
#[doc(hidden)]
pub fn _test_clear_plugins() {
    let mut st = PLUGIN_STATE.lock().unwrap();
    st.plugins.clear();
    st.grants.clear();
    st.developer_mode = false;
}
