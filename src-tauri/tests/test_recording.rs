use termex_lib::recording::asciicast::{AsciicastHeader, AsciicastEvent, AsciicastFile};
use termex_lib::recording::recorder::RecorderRegistry;

// ── Asciicast Tests ──

#[test]
fn test_header_serialize() {
    let header = AsciicastHeader::new(80, 24, Some("test".into()));
    let json = serde_json::to_string(&header).unwrap();
    assert!(json.contains("\"version\":2"));
    assert!(json.contains("\"width\":80"));
    assert!(json.contains("\"title\":\"test\""));
}

#[test]
fn test_event_serialize() {
    let event = AsciicastEvent::output(1.5, "hello world");
    let json = serde_json::to_string(&event).unwrap();
    assert_eq!(json, "[1.5,\"o\",\"hello world\"]");
}

#[test]
fn test_parse_roundtrip() {
    let file = AsciicastFile {
        header: AsciicastHeader {
            version: 2,
            width: 80,
            height: 24,
            timestamp: Some(1700000000),
            title: Some("test session".into()),
            env: None,
        },
        events: vec![
            AsciicastEvent::output(0.0, "$ "),
            AsciicastEvent::input(0.5, "ls\r"),
            AsciicastEvent::output(0.6, "file1.txt  file2.txt\r\n$ "),
        ],
    };
    let serialized = file.serialize().unwrap();
    let parsed = AsciicastFile::parse(&serialized).unwrap();
    assert_eq!(parsed.header.version, 2);
    assert_eq!(parsed.header.width, 80);
    assert_eq!(parsed.events.len(), 3);
    assert!((parsed.duration() - 0.6).abs() < 0.001);
}

#[test]
fn test_duration() {
    let file = AsciicastFile {
        header: AsciicastHeader::new(80, 24, None),
        events: vec![
            AsciicastEvent::output(0.0, "start"),
            AsciicastEvent::output(5.5, "end"),
        ],
    };
    assert!((file.duration() - 5.5).abs() < 0.001);
}

// ── Recorder Tests ──

#[tokio::test]
async fn test_recorder_lifecycle() {
    let registry = RecorderRegistry::new();
    assert!(!registry.is_recording("test-session").await);

    let _path = registry
        .start("test-session", 80, 24, Some("test".into()))
        .await
        .unwrap();
    assert!(registry.is_recording("test-session").await);

    registry.record_output("test-session", "$ ").await;
    registry.record_input("test-session", "ls\r").await;
    registry.record_output("test-session", "file.txt\r\n").await;

    let result_path = registry.stop("test-session").await.unwrap();
    assert!(result_path.exists());

    let content = std::fs::read_to_string(&result_path).unwrap();
    let file = AsciicastFile::parse(&content).unwrap();
    assert_eq!(file.events.len(), 3);
    assert_eq!(file.header.width, 80);

    let _ = std::fs::remove_file(result_path);
}
