//! DTOs for `kubectl` / `aws` CLI tool availability detection.
//!
//! Async detection implementations live in `termex-core-private`.

#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolStatus {
    pub name: String,
    pub available: bool,
    pub version: Option<String>,
    pub path: Option<String>,
}
