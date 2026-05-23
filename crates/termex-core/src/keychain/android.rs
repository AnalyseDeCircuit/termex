//! Android Keystore stub for Rust-side credential operations.
//!
//! On Android the actual credential storage is handled by the Dart
//! `KeychainBridge` (flutter_secure_storage + EncryptedSharedPreferences).
//! Rust calls back into the Dart layer via FRB callbacks registered at
//! startup; this module just routes those callbacks.
//!
//! If the FRB callback registry has not been initialised (e.g. in unit
//! tests), all operations return `Ok(None)` / `Ok(())` silently.

use super::KeychainError;
use std::sync::OnceLock;

type GetFn     = Box<dyn Fn(String) -> Option<String> + Send + Sync>;
type StoreFn   = Box<dyn Fn(String, String) -> Result<(), String> + Send + Sync>;
type DeleteFn  = Box<dyn Fn(String) -> Result<(), String> + Send + Sync>;

struct Callbacks {
    get:    GetFn,
    store:  StoreFn,
    delete: DeleteFn,
}

static CBS: OnceLock<Callbacks> = OnceLock::new();

/// Called once at app startup by the FRB bridge to wire up Dart callbacks.
pub fn register_callbacks(
    get:    GetFn,
    store:  StoreFn,
    delete: DeleteFn,
) {
    let _ = CBS.set(Callbacks { get, store, delete });
}

pub fn read_bundle() -> Result<Option<String>, KeychainError> {
    Ok(CBS.get().and_then(|c| (c.get)("__termex_store__".to_string())))
}

pub fn write_bundle(json: &str) -> Result<(), KeychainError> {
    if let Some(c) = CBS.get() {
        (c.store)("__termex_store__".to_string(), json.to_string())
            .map_err(KeychainError::OperationFailed)?;
    }
    Ok(())
}

pub fn delete_bundle() -> Result<(), KeychainError> {
    if let Some(c) = CBS.get() {
        (c.delete)("__termex_store__".to_string())
            .map_err(KeychainError::OperationFailed)?;
    }
    Ok(())
}
