//! iOS Keychain integration via `security-framework`.
//!
//! Provides generic-password CRUD using the iOS Security framework.
//! This module is compiled only on `target_os = "ios"`.
//!
//! The single-entry rule is enforced at the `keychain/mod.rs` level:
//! `init()` reads exactly once; `flush()` writes exactly once per session.

use super::KeychainError;

const SERVICE: &str = "com.termex.app";
const ACCOUNT: &str = "__termex_store__";

/// Reads the bundled JSON credential entry from the iOS Keychain.
/// Returns `None` if no entry exists yet.
pub fn read_bundle() -> Result<Option<String>, KeychainError> {
    use security_framework::passwords::get_generic_password;

    match get_generic_password(SERVICE, ACCOUNT) {
        Ok(bytes) => {
            let s = String::from_utf8(bytes)
                .map_err(|e| KeychainError::OperationFailed(e.to_string()))?;
            Ok(Some(s))
        }
        Err(e) => {
            // errSecItemNotFound (-25300) means the entry doesn't exist yet.
            if e.code() == -25300 {
                Ok(None)
            } else {
                Err(KeychainError::OperationFailed(e.to_string()))
            }
        }
    }
}

/// Writes the bundled JSON credential entry to the iOS Keychain.
pub fn write_bundle(json: &str) -> Result<(), KeychainError> {
    use security_framework::passwords::set_generic_password;

    set_generic_password(SERVICE, ACCOUNT, json.as_bytes())
        .map_err(|e| KeychainError::OperationFailed(e.to_string()))
}

/// Deletes the bundled credential entry from the iOS Keychain.
pub fn delete_bundle() -> Result<(), KeychainError> {
    use security_framework::passwords::delete_generic_password;

    delete_generic_password(SERVICE, ACCOUNT)
        .map_err(|e| KeychainError::OperationFailed(e.to_string()))
}
