use termex_lib::crypto::aes::{encrypt, decrypt};
use termex_lib::crypto::kdf;

// ── AES-256-GCM Tests ──

#[test]
fn test_encrypt_decrypt_roundtrip() {
    let key = [0x42u8; 32];
    let plaintext = b"hello, termex!";
    let encrypted = encrypt(&key, plaintext).unwrap();
    assert_ne!(encrypted, plaintext);
    // NONCE(12) + plaintext + TAG(16)
    assert_eq!(encrypted.len(), 12 + plaintext.len() + 16);
    let decrypted = decrypt(&key, &encrypted).unwrap();
    assert_eq!(decrypted, plaintext);
}

#[test]
fn test_decrypt_wrong_key_fails() {
    let key1 = [0x42u8; 32];
    let key2 = [0x43u8; 32];
    let encrypted = encrypt(&key1, b"secret").unwrap();
    assert!(decrypt(&key2, &encrypted).is_err());
}

#[test]
fn test_decrypt_tampered_data_fails() {
    let key = [0x42u8; 32];
    let mut encrypted = encrypt(&key, b"secret").unwrap();
    let mid = encrypted.len() / 2;
    encrypted[mid] ^= 0xFF;
    assert!(decrypt(&key, &encrypted).is_err());
}

#[test]
fn test_decrypt_too_short() {
    let key = [0x42u8; 32];
    assert!(decrypt(&key, &[0u8; 10]).is_err());
}

#[test]
fn test_empty_plaintext() {
    let key = [0x42u8; 32];
    let encrypted = encrypt(&key, b"").unwrap();
    let decrypted = decrypt(&key, &encrypted).unwrap();
    assert!(decrypted.is_empty());
}

#[test]
fn test_unique_nonces() {
    let key = [0x42u8; 32];
    let enc1 = encrypt(&key, b"same").unwrap();
    let enc2 = encrypt(&key, b"same").unwrap();
    assert_ne!(enc1, enc2);
}

// ── KDF Tests ──

#[test]
fn test_derive_key_deterministic() {
    let salt = [0xABu8; 16];
    let key1 = kdf::derive_key("my-password", &salt).unwrap();
    let key2 = kdf::derive_key("my-password", &salt).unwrap();
    assert_eq!(key1, key2);
}

#[test]
fn test_different_passwords_different_keys() {
    let salt = [0xABu8; 16];
    let key1 = kdf::derive_key("password-a", &salt).unwrap();
    let key2 = kdf::derive_key("password-b", &salt).unwrap();
    assert_ne!(key1, key2);
}

#[test]
fn test_different_salts_different_keys() {
    let salt1 = [0xAAu8; 16];
    let salt2 = [0xBBu8; 16];
    let key1 = kdf::derive_key("same-password", &salt1).unwrap();
    let key2 = kdf::derive_key("same-password", &salt2).unwrap();
    assert_ne!(key1, key2);
}

#[test]
fn test_derive_key_new_generates_unique_salt() {
    let (_, salt1) = kdf::derive_key_new("password").unwrap();
    let (_, salt2) = kdf::derive_key_new("password").unwrap();
    assert_ne!(salt1, salt2);
}

#[test]
fn test_key_length() {
    let (key, _) = kdf::derive_key_new("password").unwrap();
    assert_eq!(key.len(), 32);
}
