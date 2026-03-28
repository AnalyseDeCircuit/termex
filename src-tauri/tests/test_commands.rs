use termex_lib::crypto::{aes, kdf};

// ── Settings Command Tests ──

#[test]
fn test_setting_entry_serialize() {
    #[derive(serde::Serialize)]
    struct SettingEntry {
        key: String,
        value: String,
    }
    let entry = SettingEntry {
        key: "theme".into(),
        value: "dark".into(),
    };
    let json = serde_json::to_string(&entry).unwrap();
    assert!(json.contains("\"key\":\"theme\""));
    assert!(json.contains("\"value\":\"dark\""));
}

// ── Config Export/Import Tests ──

#[test]
fn test_export_file_format_roundtrip() {
    use flate2::write::GzEncoder;
    use flate2::read::GzDecoder;
    use flate2::Compression;
    use std::io::{Write, Read};
    use termex_lib::crypto::{aes, kdf};

    #[derive(serde::Serialize, serde::Deserialize)]
    struct ExportPayload {
        servers: Vec<serde_json::Value>,
        groups: Vec<serde_json::Value>,
        port_forwards: Vec<serde_json::Value>,
        settings: Vec<serde_json::Value>,
    }

    let magic = b"TMEX";
    let format_version: u16 = 1;

    let password = "test-password";
    let payload = ExportPayload {
        servers: vec![serde_json::json!({"id": "s1", "name": "test"})],
        groups: vec![],
        port_forwards: vec![],
        settings: vec![],
    };

    let json = serde_json::to_vec(&payload).unwrap();

    // Compress
    let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(&json).unwrap();
    let compressed = encoder.finish().unwrap();

    // Encrypt
    let (key, salt) = kdf::derive_key_new(password).unwrap();
    let encrypted = aes::encrypt(&key, &compressed).unwrap();

    // Build file bytes
    let mut file_data = Vec::new();
    file_data.extend_from_slice(magic);
    file_data.extend_from_slice(&format_version.to_le_bytes());
    file_data.extend_from_slice(&salt);
    file_data.extend_from_slice(&encrypted);

    // Parse back
    assert_eq!(&file_data[0..4], magic);
    let ver = u16::from_le_bytes([file_data[4], file_data[5]]);
    assert_eq!(ver, 1);

    let salt2: [u8; 16] = file_data[6..22].try_into().unwrap();
    let key2 = kdf::derive_key(password, &salt2).unwrap();
    let decrypted = aes::decrypt(&key2, &file_data[22..]).unwrap();

    let mut decoder = GzDecoder::new(&decrypted[..]);
    let mut json_out = Vec::new();
    decoder.read_to_end(&mut json_out).unwrap();

    let result: ExportPayload = serde_json::from_slice(&json_out).unwrap();
    assert_eq!(result.servers.len(), 1);
    assert_eq!(result.servers[0]["name"], "test");
}

#[test]
fn test_export_magic_bytes() {
    let magic = b"TMEX";
    assert_eq!(magic.len(), 4);
    assert_eq!(magic[0], b'T');
    assert_eq!(magic[3], b'X');
}

#[test]
fn test_export_wrong_password_fails() {
    let password = "correct";
    let wrong = "incorrect";

    let (key, salt) = kdf::derive_key_new(password).unwrap();
    let encrypted = aes::encrypt(&key, b"test data").unwrap();

    let wrong_key = kdf::derive_key(wrong, &salt).unwrap();
    assert!(aes::decrypt(&wrong_key, &encrypted).is_err());
}

#[test]
fn test_export_empty_payload() {
    use flate2::write::GzEncoder;
    use flate2::Compression;
    use std::io::Write;

    let json = b"{}";
    let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(json).unwrap();
    let compressed = encoder.finish().unwrap();

    let (key, _) = kdf::derive_key_new("pass").unwrap();
    let encrypted = aes::encrypt(&key, &compressed).unwrap();
    let decrypted = aes::decrypt(&key, &encrypted).unwrap();
    assert_eq!(decrypted, compressed);
}
