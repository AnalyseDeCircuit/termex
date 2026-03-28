use termex_lib::sftp::session::{FileEntry, TransferProgress};

#[test]
fn test_file_entry_serialize() {
    let entry = FileEntry {
        name: "test.txt".to_string(),
        is_dir: false,
        is_symlink: false,
        size: 1024,
        permissions: Some("rwxr-xr-x".to_string()),
        uid: Some(1000),
        gid: Some(1000),
        mtime: Some(1700000000),
    };
    let json = serde_json::to_string(&entry).unwrap();
    assert!(json.contains("\"name\":\"test.txt\""));
    assert!(json.contains("\"isDir\":false"));
    assert!(json.contains("\"size\":1024"));
}

#[test]
fn test_transfer_progress_serialize() {
    let progress = TransferProgress {
        transfer_id: "abc".to_string(),
        remote_path: "/tmp/file.txt".to_string(),
        transferred: 512,
        total: 1024,
        done: false,
    };
    let json = serde_json::to_string(&progress).unwrap();
    assert!(json.contains("\"transferId\":\"abc\""));
    assert!(json.contains("\"transferred\":512"));
    assert!(json.contains("\"done\":false"));
}
