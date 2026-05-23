//! Security status surface for the Settings → Security tab.
//!
//! Mirrors `SecurityTab.vue` in the Tauri build. Reports whether the OS
//! keychain is reachable and how many credentials are currently cached in
//! `__termex_store__`. The Dart UI uses this to draw the "Protection"
//! card.

use flutter_rust_bridge::frb;

#[frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SecurityStatus {
    /// True when `termex_core::keychain::is_available()` returns true —
    /// i.e. the OS keychain accepted the single `__termex_store__` entry
    /// and the cache was loaded successfully at startup.
    pub keychain_available: bool,
    /// Number of credentials in the in-memory cache (= JSON entries inside
    /// `__termex_store__`). Reflects what `flush()` would write back.
    pub keychain_credential_count: u32,
}

/// Returns a snapshot of the current security posture.
pub fn security_status() -> SecurityStatus {
    SecurityStatus {
        keychain_available: termex_core::keychain::is_available(),
        keychain_credential_count: termex_core::keychain::cached_count() as u32,
    }
}
