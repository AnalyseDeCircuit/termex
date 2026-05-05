/// `.termex` backup file format (v0.46 spec §4.8.5).
///
/// File layout:
///
/// ```text
/// ┌────────────────────────────────┐
/// │ Magic:   "TRMX"   (4 bytes)    │
/// │ Version: u16 LE   (2 bytes)    │ = 2
/// │ KDF:     u8       (1 byte)     │ = 1 (Argon2id)
/// │ Salt:    [u8; 16] (16 bytes)   │ random
/// │ Nonce:   [u8; 12] (12 bytes)   │ random (GCM)
/// │ Ciphertext:       (remainder)  │ AES-256-GCM(JSON), includes 16B tag suffix
/// └────────────────────────────────┘
/// ```
///
/// The plaintext JSON uses `schema_version: 2` and matches the envelope used
/// by `settings_export` in the non-encrypted path for downward compatibility.
use flutter_rust_bridge::frb;

use termex_core::crypto::aes;
use termex_core::crypto::kdf;

// ─── Header constants ───────────────────────────────────────────────────────

const MAGIC: &[u8; 4] = b"TRMX";
const VERSION: u16 = 2;
const KDF_ARGON2ID: u8 = 1;
const SALT_LEN: usize = 16;
const HEADER_LEN: usize = 4 + 2 + 1 + SALT_LEN; // magic + version + kdf + salt
                                                 // (nonce is prepended by aes::encrypt output)

/// Serialises `payload_json` into a password-protected `.termex` file.
#[frb]
pub fn backup_encrypt_to_file(
    path: String,
    password: String,
    payload_json: String,
) -> Result<(), String> {
    if password.is_empty() {
        return Err("Backup password must not be empty".into());
    }

    let (key, salt) = kdf::derive_key_new(&password).map_err(|e| e.to_string())?;
    let body = aes::encrypt(&*key, payload_json.as_bytes()).map_err(|e| e.to_string())?;

    let mut out = Vec::with_capacity(HEADER_LEN + body.len());
    out.extend_from_slice(MAGIC);
    out.extend_from_slice(&VERSION.to_le_bytes());
    out.push(KDF_ARGON2ID);
    out.extend_from_slice(&salt);
    out.extend_from_slice(&body);

    std::fs::write(&path, out).map_err(|e| format!("write backup: {e}"))?;
    Ok(())
}

/// Decrypts a `.termex` file and returns the JSON payload.
#[frb]
pub fn backup_decrypt_from_file(path: String, password: String) -> Result<String, String> {
    let bytes = std::fs::read(&path).map_err(|e| format!("read backup: {e}"))?;
    if bytes.len() < HEADER_LEN {
        return Err("Backup file truncated".into());
    }
    if &bytes[0..4] != MAGIC {
        return Err("Not a Termex backup (magic mismatch)".into());
    }
    let version = u16::from_le_bytes([bytes[4], bytes[5]]);
    if version != VERSION {
        return Err(format!("Unsupported backup version: {version}"));
    }
    let kdf_id = bytes[6];
    if kdf_id != KDF_ARGON2ID {
        return Err(format!("Unsupported KDF: {kdf_id}"));
    }

    let mut salt = [0u8; SALT_LEN];
    salt.copy_from_slice(&bytes[7..7 + SALT_LEN]);

    let key = kdf::derive_key(&password, &salt).map_err(|e| e.to_string())?;
    let body = &bytes[HEADER_LEN..];
    let plaintext = aes::decrypt(&*key, body).map_err(|_| "Decryption failed — wrong password?".to_string())?;

    String::from_utf8(plaintext).map_err(|_| "Backup payload is not valid UTF-8".into())
}

/// Returns the magic-number + version header this binary emits, for UI
/// display on the backup settings page.
#[frb]
pub fn backup_format_description() -> String {
    format!(
        "Termex backup v{} (AES-256-GCM + Argon2id m=64MB t=3 p=4)",
        VERSION
    )
}
