use crate::db_state;
use termex_core::crypto::{aes, kdf};
use termex_core::storage::db::Database;

/// Verify the master password against the stored verification token.
///
/// Matches the Tauri/Vue stack scheme: the database itself is plain SQLite
/// (not SQLCipher-encrypted). The master password is verified by deriving
/// an Argon2id key from `password + master_salt` and decrypting the
/// `master_verify` token; if the plaintext is `TERMEX_VERIFY`, the password
/// is correct.
///
/// Returns `Ok(true)` on success, `Ok(false)` if the password is wrong,
/// `Err(...)` on I/O or schema corruption.
pub fn verify_master_password(password: String) -> Result<bool, String> {
    // Open the DB without SQLCipher — the existing DB created by the
    // Tauri build is plain SQLite with field-level AES encryption.
    let db = match Database::open(None) {
        Ok(d) => d,
        Err(e) => return Err(e.to_string()),
    };

    let (salt, verify_token) = match load_salt_and_token(&db) {
        Ok(t) => t,
        Err(e) => return Err(e),
    };

    let key = kdf::derive_key(&password, &salt).map_err(|e| e.to_string())?;

    match aes::decrypt(&*key, &verify_token) {
        Ok(plaintext) if plaintext == b"TERMEX_VERIFY" => {
            db_state::set_db(db);
            Ok(true)
        }
        _ => Ok(false),
    }
}

/// Unlock the database with a master password. Same verification logic as
/// `verify_master_password` but returns `Err` instead of `Ok(false)` on a
/// wrong password.
pub fn unlock_database(password: String) -> Result<(), String> {
    match verify_master_password(password) {
        Ok(true) => Ok(()),
        Ok(false) => Err("Wrong master password".into()),
        Err(e) => Err(e),
    }
}

/// Reads `master_salt` and `master_verify` rows from the `settings` table
/// and hex-decodes them.
fn load_salt_and_token(db: &Database) -> Result<([u8; 16], Vec<u8>), String> {
    db.with_conn(|conn| {
        let salt_hex: String = conn.query_row(
            "SELECT value FROM settings WHERE key = 'master_salt'",
            [],
            |row| row.get(0),
        )?;
        let token_hex: String = conn.query_row(
            "SELECT value FROM settings WHERE key = 'master_verify'",
            [],
            |row| row.get(0),
        )?;
        let salt_bytes = hex_decode(&salt_hex);
        if salt_bytes.len() != 16 {
            return Err(rusqlite::Error::InvalidParameterName(
                "corrupt master salt".into(),
            ));
        }
        let mut salt = [0u8; 16];
        salt.copy_from_slice(&salt_bytes);
        Ok((salt, hex_decode(&token_hex)))
    })
    .map_err(|e| e.to_string())
}

fn hex_decode(s: &str) -> Vec<u8> {
    (0..s.len())
        .step_by(2)
        .filter_map(|i| {
            s.get(i..i + 2)
                .and_then(|byte| u8::from_str_radix(byte, 16).ok())
        })
        .collect()
}
