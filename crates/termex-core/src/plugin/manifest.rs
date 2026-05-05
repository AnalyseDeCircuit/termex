use serde::{Deserialize, Serialize};

/// Plugin manifest (plugin.json) schema.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PluginManifest {
    /// Unique plugin identifier.
    pub id: String,
    /// Display name.
    pub name: String,
    /// Plugin version (semver).
    pub version: String,
    /// Short description.
    pub description: String,
    /// Plugin author.
    pub author: Option<String>,
    /// Homepage URL.
    pub homepage: Option<String>,
    /// Required permissions.
    #[serde(default)]
    pub permissions: Vec<PluginPermission>,
    /// Entry point file (relative to plugin directory).
    pub entry: String,
    /// Minimum Termex version required.
    pub min_termex_version: Option<String>,
}

/// Plugin permission types.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PluginPermission {
    /// Read terminal output data.
    TerminalRead,
    /// Write to terminal input.
    TerminalWrite,
    /// Access server connection info (host, port, username).
    ServerInfo,
    /// Make network requests.
    Network,
    /// Read/write plugin-specific storage.
    Storage,
    /// Access clipboard.
    Clipboard,
    /// Show notifications.
    Notification,
}

impl PluginManifest {
    /// Parses a manifest from JSON string.
    pub fn parse(json: &str) -> Result<Self, super::PluginError> {
        let manifest: Self = serde_json::from_str(json)?;
        manifest.validate()?;
        Ok(manifest)
    }

    /// Validates the manifest fields.
    fn validate(&self) -> Result<(), super::PluginError> {
        if self.id.is_empty() {
            return Err(super::PluginError::InvalidManifest("id is required".into()));
        }
        if self.name.is_empty() {
            return Err(super::PluginError::InvalidManifest(
                "name is required".into(),
            ));
        }
        if self.entry.is_empty() {
            return Err(super::PluginError::InvalidManifest(
                "entry is required".into(),
            ));
        }
        Ok(())
    }
}