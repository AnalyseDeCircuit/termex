//! Tests for the `.termex` backup file format (v0.46 spec §4.8.5).

use tempfile::TempDir;
use termex_flutter_bridge::api::backup::*;

#[test]
fn test_backup_encrypt_decrypt_roundtrip() {
    let dir = TempDir::new().unwrap();
    let path = dir.path().join("b.termex").to_string_lossy().to_string();

    let payload = r#"{"schema_version":2,"settings":{"themeMode":"dark"}}"#;
    backup_encrypt_to_file(path.clone(), "strong-pw".into(), payload.into())
        .expect("encrypt should succeed");

    let roundtrip =
        backup_decrypt_from_file(path, "strong-pw".into()).expect("decrypt should succeed");
    assert_eq!(roundtrip, payload);
}

#[test]
fn test_backup_rejects_empty_password() {
    let dir = TempDir::new().unwrap();
    let path = dir.path().join("b.termex").to_string_lossy().to_string();
    let err = backup_encrypt_to_file(path, "".into(), "body".into()).unwrap_err();
    assert!(err.contains("Backup password"));
}

#[test]
fn test_backup_wrong_password_fails_decrypt() {
    let dir = TempDir::new().unwrap();
    let path = dir.path().join("b.termex").to_string_lossy().to_string();

    backup_encrypt_to_file(path.clone(), "right".into(), "hi".into()).unwrap();
    let err = backup_decrypt_from_file(path, "wrong".into()).unwrap_err();
    assert!(err.contains("Decryption failed"));
}

#[test]
fn test_backup_rejects_wrong_magic() {
    let dir = TempDir::new().unwrap();
    let path = dir.path().join("b.termex");
    std::fs::write(&path, b"XXXXsome random bytes not a termex backup").unwrap();

    let err =
        backup_decrypt_from_file(path.to_string_lossy().to_string(), "pw".into()).unwrap_err();
    assert!(err.contains("magic"));
}

#[test]
fn test_backup_format_description_mentions_version_and_kdf() {
    let desc = backup_format_description();
    assert!(desc.contains("v2"));
    assert!(desc.contains("Argon2id"));
    assert!(desc.contains("AES-256-GCM"));
}

#[test]
fn test_backup_file_has_magic_header() {
    let dir = TempDir::new().unwrap();
    let path = dir.path().join("b.termex").to_string_lossy().to_string();
    backup_encrypt_to_file(path.clone(), "pw".into(), "payload".into()).unwrap();

    let bytes = std::fs::read(&path).unwrap();
    assert!(bytes.len() > 23, "must have header + body");
    assert_eq!(&bytes[0..4], b"TRMX");
    // Version = 2 (LE).
    assert_eq!(&bytes[4..6], &[2u8, 0u8]);
    // KDF id = 1 (Argon2id).
    assert_eq!(bytes[6], 1u8);
}
