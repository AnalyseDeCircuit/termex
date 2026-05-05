use std::path::PathBuf;

use termex_core::ssh::config_parser;

use super::server::{AuthType, ServerInput, create_server};

/// A preview of a single SSH config entry to be shown before import.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SshConfigPreviewEntry {
    /// The Host alias from the config file.
    pub host_alias: String,
    /// The resolved hostname (may differ from host_alias via HostName directive).
    pub hostname: String,
    /// SSH port (default 22).
    pub port: u16,
    /// Username for the connection.
    pub username: String,
    /// Optional path to an identity file.
    pub identity_file: Option<String>,
    /// Whether this entry uses a wildcard Host pattern.
    pub is_wildcard: bool,
}

/// Counts for a completed SSH config import.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SshConfigImportResult {
    /// Number of entries successfully imported.
    pub imported: u32,
    /// Number of entries skipped (already exist or wildcard).
    pub skipped: u32,
}

/// Returns the default path to the user's SSH config file (`~/.ssh/config`).
fn default_ssh_config_path() -> PathBuf {
    dirs::home_dir()
        .unwrap_or_else(|| PathBuf::from("~"))
        .join(".ssh")
        .join("config")
}

/// Parses the SSH config file at `path` (defaults to `~/.ssh/config`) and returns
/// a preview of all non-wildcard entries suitable for display in an import dialog.
pub fn preview_ssh_config_import(
    path: Option<String>,
) -> Result<Vec<SshConfigPreviewEntry>, String> {
    let config_path = path
        .map(PathBuf::from)
        .unwrap_or_else(default_ssh_config_path);

    let result = config_parser::parse_ssh_config(&config_path)?;

    let entries = result
        .entries
        .into_iter()
        .filter(|e| !e.is_wildcard)
        .map(|e| SshConfigPreviewEntry {
            host_alias: e.host_alias,
            hostname: e.hostname,
            port: e.port,
            username: e.user,
            identity_file: e.identity_file,
            is_wildcard: e.is_wildcard,
        })
        .collect();

    Ok(entries)
}

/// Imports selected SSH config entries as server records.
///
/// - `path`: path to the SSH config file; defaults to `~/.ssh/config`.
/// - `selected_aliases`: only entries whose `host_alias` is in this list are imported.
///
/// Duplicate entries (same host + port + username) are skipped.
pub fn import_ssh_config(
    path: Option<String>,
    selected_aliases: Vec<String>,
) -> Result<SshConfigImportResult, String> {
    let config_path = path
        .map(PathBuf::from)
        .unwrap_or_else(default_ssh_config_path);

    let parse_result = config_parser::parse_ssh_config(&config_path)?;

    // Fetch existing servers to detect duplicates.
    let existing = crate::db_state::with_db(|db| {
        db.with_conn(|conn| {
            let mut stmt = conn.prepare(
                "SELECT host, port, username FROM servers",
            )?;
            let rows = stmt.query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, i64>(1)? as u16,
                    row.get::<_, String>(2)?,
                ))
            })?;
            rows.collect::<rusqlite::Result<Vec<_>>>()
        })
        .map_err(|e| e.to_string())
    })?;

    let mut imported: u32 = 0;
    let mut skipped: u32 = 0;

    for entry in parse_result.entries {
        // Skip wildcards and entries not in the selection list
        if entry.is_wildcard || !selected_aliases.contains(&entry.host_alias) {
            skipped += 1;
            continue;
        }

        // Skip duplicates: same host + port + username already in DB
        let is_duplicate = existing
            .iter()
            .any(|(h, p, u)| h == &entry.hostname && *p == entry.port && u == &entry.user);

        if is_duplicate {
            skipped += 1;
            continue;
        }

        let auth_type = if entry.identity_file.is_some() {
            AuthType::Key
        } else {
            AuthType::Password
        };

        let input = ServerInput {
            name: entry.host_alias.clone(),
            host: entry.hostname.clone(),
            port: entry.port,
            username: entry.user.clone(),
            auth_type,
            password: None,
            key_path: entry.identity_file.clone(),
            group_id: None,
            tags: vec![],
        };

        match create_server(input) {
            Ok(_) => imported += 1,
            Err(_) => skipped += 1,
        }
    }

    Ok(SshConfigImportResult { imported, skipped })
}
