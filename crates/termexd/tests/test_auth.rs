//! Tests for bearer-token generation + verification.

use std::fs;
use std::os::unix::fs::PermissionsExt;

use tempfile::TempDir;

// Re-import via the binary crate's lib-style path: we expose modules
// via a tiny test-only entry to keep the bin crate uniform.
#[path = "../src/auth.rs"]
#[allow(dead_code)]
mod auth;

#[path = "../src/error.rs"]
#[allow(dead_code)]
mod error;

#[test]
fn load_or_create_generates_64_char_hex_token() {
    let tmp = TempDir::new().unwrap();
    let token = auth::load_or_create_token(&tmp.path().to_path_buf()).unwrap();
    assert_eq!(token.len(), 64, "32 bytes hex = 64 chars");
    assert!(token.chars().all(|c| c.is_ascii_hexdigit()));
}

#[test]
fn load_or_create_persists_to_file_with_0600_perms() {
    let tmp = TempDir::new().unwrap();
    let token = auth::load_or_create_token(&tmp.path().to_path_buf()).unwrap();
    let path = tmp.path().join("daemon.token");
    assert!(path.exists());
    let perms = fs::metadata(&path).unwrap().permissions();
    assert_eq!(perms.mode() & 0o777, 0o600, "must be chmod 0600");
    let on_disk = fs::read_to_string(&path).unwrap();
    assert_eq!(on_disk.trim(), token);
}

#[test]
fn load_or_create_reuses_existing_token() {
    let tmp = TempDir::new().unwrap();
    let first = auth::load_or_create_token(&tmp.path().to_path_buf()).unwrap();
    let second = auth::load_or_create_token(&tmp.path().to_path_buf()).unwrap();
    assert_eq!(first, second);
}

#[test]
fn load_or_create_regenerates_when_file_empty() {
    let tmp = TempDir::new().unwrap();
    fs::create_dir_all(tmp.path()).unwrap();
    fs::write(tmp.path().join("daemon.token"), "").unwrap();
    let token = auth::load_or_create_token(&tmp.path().to_path_buf()).unwrap();
    assert_eq!(token.len(), 64);
}

#[test]
fn verify_token_accepts_match() {
    assert!(auth::verify_token("abcdef", "abcdef"));
}

#[test]
fn verify_token_rejects_mismatch() {
    assert!(!auth::verify_token("abcdef", "abcdez"));
}

#[test]
fn verify_token_rejects_different_lengths() {
    assert!(!auth::verify_token("abcdef", "abcde"));
    assert!(!auth::verify_token("abcdef", "abcdefg"));
}

#[test]
fn verify_token_constant_time_full_walk() {
    // Sanity: full-mismatch in last byte still returns false.
    let a = "a".repeat(64);
    let mut b = a.clone();
    b.replace_range(63..64, "b");
    assert!(!auth::verify_token(&a, &b));
}
