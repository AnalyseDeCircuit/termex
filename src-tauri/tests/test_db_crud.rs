//! Integration tests for database CRUD operations.
//! Tests server, group, settings, and AI provider operations directly on SQLite.

use rusqlite::Connection;
use termex_lib::storage::migrations::run_migrations;

fn setup_db() -> Connection {
    let conn = Connection::open_in_memory().unwrap();
    conn.pragma_update(None, "foreign_keys", "ON").unwrap();
    run_migrations(&conn).unwrap();
    conn
}

// ── Server CRUD ──

#[test]
fn test_server_create_and_list() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO servers (id, name, host, port, username, auth_type, encoding, tags, created_at, updated_at)
         VALUES ('s1', 'Test Server', '192.168.1.1', 22, 'root', 'password', 'UTF-8', '[]', '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();

    let count: i32 = conn.query_row("SELECT COUNT(*) FROM servers", [], |r| r.get(0)).unwrap();
    assert_eq!(count, 1);

    let name: String = conn.query_row("SELECT name FROM servers WHERE id='s1'", [], |r| r.get(0)).unwrap();
    assert_eq!(name, "Test Server");
}

#[test]
fn test_server_update() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO servers (id, name, host, port, username, auth_type, encoding, tags, created_at, updated_at)
         VALUES ('s1', 'Old', '1.1.1.1', 22, 'root', 'password', 'UTF-8', '[]', '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();

    conn.execute("UPDATE servers SET name='New', host='2.2.2.2' WHERE id='s1'", []).unwrap();

    let (name, host): (String, String) = conn.query_row(
        "SELECT name, host FROM servers WHERE id='s1'", [], |r| Ok((r.get(0)?, r.get(1)?)),
    ).unwrap();
    assert_eq!(name, "New");
    assert_eq!(host, "2.2.2.2");
}

#[test]
fn test_server_delete() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO servers (id, name, host, port, username, auth_type, encoding, tags, created_at, updated_at)
         VALUES ('s1', 'Test', '1.1.1.1', 22, 'root', 'password', 'UTF-8', '[]', '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();

    conn.execute("DELETE FROM servers WHERE id='s1'", []).unwrap();
    let count: i32 = conn.query_row("SELECT COUNT(*) FROM servers", [], |r| r.get(0)).unwrap();
    assert_eq!(count, 0);
}

#[test]
fn test_server_with_group() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO groups (id, name, created_at, updated_at) VALUES ('g1', 'Production', '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();
    conn.execute(
        "INSERT INTO servers (id, name, host, port, username, auth_type, group_id, encoding, tags, created_at, updated_at)
         VALUES ('s1', 'Web', '1.1.1.1', 22, 'root', 'password', 'g1', 'UTF-8', '[]', '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();

    let gid: Option<String> = conn.query_row("SELECT group_id FROM servers WHERE id='s1'", [], |r| r.get(0)).unwrap();
    assert_eq!(gid, Some("g1".to_string()));
}

#[test]
fn test_server_delete_group_cascades_null() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO groups (id, name, created_at, updated_at) VALUES ('g1', 'Prod', '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();
    conn.execute(
        "INSERT INTO servers (id, name, host, port, username, auth_type, group_id, encoding, tags, created_at, updated_at)
         VALUES ('s1', 'Web', '1.1.1.1', 22, 'root', 'password', 'g1', 'UTF-8', '[]', '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();

    conn.execute("DELETE FROM groups WHERE id='g1'", []).unwrap();

    // Server should still exist but with NULL group_id
    let gid: Option<String> = conn.query_row("SELECT group_id FROM servers WHERE id='s1'", [], |r| r.get(0)).unwrap();
    assert!(gid.is_none());
}

// ── Group CRUD ──

#[test]
fn test_group_create_and_list() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO groups (id, name, color, icon, created_at, updated_at)
         VALUES ('g1', 'Production', '#ff0000', 'server', '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();

    let (name, color): (String, String) = conn.query_row(
        "SELECT name, color FROM groups WHERE id='g1'", [], |r| Ok((r.get(0)?, r.get(1)?)),
    ).unwrap();
    assert_eq!(name, "Production");
    assert_eq!(color, "#ff0000");
}

#[test]
fn test_group_with_parent() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO groups (id, name, created_at, updated_at) VALUES ('g1', 'Parent', '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();
    conn.execute(
        "INSERT INTO groups (id, name, parent_id, created_at, updated_at) VALUES ('g2', 'Child', 'g1', '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();

    let pid: Option<String> = conn.query_row("SELECT parent_id FROM groups WHERE id='g2'", [], |r| r.get(0)).unwrap();
    assert_eq!(pid, Some("g1".to_string()));
}

// ── Settings CRUD ──

#[test]
fn test_settings_insert_and_get() {
    let conn = setup_db();
    conn.execute("INSERT INTO settings (key, value, updated_at) VALUES ('theme', 'dark', '2024-01-01')", []).unwrap();

    let val: String = conn.query_row("SELECT value FROM settings WHERE key='theme'", [], |r| r.get(0)).unwrap();
    assert_eq!(val, "dark");
}

#[test]
fn test_settings_upsert() {
    let conn = setup_db();
    conn.execute("INSERT INTO settings (key, value, updated_at) VALUES ('theme', 'dark', '2024-01-01')", []).unwrap();
    conn.execute(
        "INSERT INTO settings (key, value, updated_at) VALUES ('theme', 'light', '2024-01-02') ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at",
        [],
    ).unwrap();

    let val: String = conn.query_row("SELECT value FROM settings WHERE key='theme'", [], |r| r.get(0)).unwrap();
    assert_eq!(val, "light");
}

#[test]
fn test_settings_delete() {
    let conn = setup_db();
    conn.execute("INSERT INTO settings (key, value, updated_at) VALUES ('lang', 'en', '2024-01-01')", []).unwrap();
    conn.execute("DELETE FROM settings WHERE key='lang'", []).unwrap();

    let count: i32 = conn.query_row("SELECT COUNT(*) FROM settings WHERE key='lang'", [], |r| r.get(0)).unwrap();
    assert_eq!(count, 0);
}

#[test]
fn test_settings_get_all() {
    let conn = setup_db();
    conn.execute("INSERT INTO settings (key, value, updated_at) VALUES ('a', '1', '2024-01-01')", []).unwrap();
    conn.execute("INSERT INTO settings (key, value, updated_at) VALUES ('b', '2', '2024-01-01')", []).unwrap();

    let count: i32 = conn.query_row("SELECT COUNT(*) FROM settings", [], |r| r.get(0)).unwrap();
    assert_eq!(count, 2);
}

// ── AI Provider CRUD ──

#[test]
fn test_ai_provider_create() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO ai_providers (id, name, provider_type, model, max_tokens, temperature, is_default, created_at, updated_at)
         VALUES ('p1', 'GPT', 'openai', 'gpt-4o', 4096, 0.7, 1, '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();

    let (name, model, is_default): (String, String, bool) = conn.query_row(
        "SELECT name, model, is_default FROM ai_providers WHERE id='p1'",
        [], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
    ).unwrap();
    assert_eq!(name, "GPT");
    assert_eq!(model, "gpt-4o");
    assert!(is_default);
}

#[test]
fn test_ai_provider_update_default() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO ai_providers (id, name, provider_type, model, is_default, created_at, updated_at)
         VALUES ('p1', 'A', 'openai', 'gpt-4o', 1, '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();
    conn.execute(
        "INSERT INTO ai_providers (id, name, provider_type, model, is_default, created_at, updated_at)
         VALUES ('p2', 'B', 'claude', 'claude-sonnet', 0, '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();

    // Set p2 as default
    conn.execute("UPDATE ai_providers SET is_default = 0", []).unwrap();
    conn.execute("UPDATE ai_providers SET is_default = 1 WHERE id='p2'", []).unwrap();

    let d1: bool = conn.query_row("SELECT is_default FROM ai_providers WHERE id='p1'", [], |r| r.get(0)).unwrap();
    let d2: bool = conn.query_row("SELECT is_default FROM ai_providers WHERE id='p2'", [], |r| r.get(0)).unwrap();
    assert!(!d1);
    assert!(d2);
}

#[test]
fn test_ai_provider_with_keychain_id() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO ai_providers (id, name, provider_type, model, api_key_keychain_id, is_default, created_at, updated_at)
         VALUES ('p1', 'Test', 'openai', 'gpt-4o', 'termex:ai:apikey:p1', 1, '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();

    let kc_id: Option<String> = conn.query_row(
        "SELECT api_key_keychain_id FROM ai_providers WHERE id='p1'", [], |r| r.get(0),
    ).unwrap();
    assert_eq!(kc_id, Some("termex:ai:apikey:p1".to_string()));

    // api_key_enc should be NULL when using keychain
    let enc: Option<Vec<u8>> = conn.query_row(
        "SELECT api_key_enc FROM ai_providers WHERE id='p1'", [], |r| r.get(0),
    ).unwrap();
    assert!(enc.is_none());
}

#[test]
fn test_ai_provider_delete() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO ai_providers (id, name, provider_type, model, is_default, created_at, updated_at)
         VALUES ('p1', 'Test', 'openai', 'gpt-4o', 0, '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();

    conn.execute("DELETE FROM ai_providers WHERE id='p1'", []).unwrap();
    let count: i32 = conn.query_row("SELECT COUNT(*) FROM ai_providers", [], |r| r.get(0)).unwrap();
    assert_eq!(count, 0);
}

// ── Port Forward CRUD ──

#[test]
fn test_port_forward_create() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO servers (id, name, host, port, username, auth_type, encoding, tags, created_at, updated_at)
         VALUES ('s1', 'Test', '1.1.1.1', 22, 'root', 'password', 'UTF-8', '[]', '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();
    conn.execute(
        "INSERT INTO port_forwards (id, server_id, forward_type, local_host, local_port, remote_host, remote_port, created_at)
         VALUES ('pf1', 's1', 'local', '127.0.0.1', 8080, 'localhost', 80, '2024-01-01')",
        [],
    ).unwrap();

    let (ftype, lport): (String, i32) = conn.query_row(
        "SELECT forward_type, local_port FROM port_forwards WHERE id='pf1'",
        [], |r| Ok((r.get(0)?, r.get(1)?)),
    ).unwrap();
    assert_eq!(ftype, "local");
    assert_eq!(lport, 8080);
}

#[test]
fn test_port_forward_cascade_delete() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO servers (id, name, host, port, username, auth_type, encoding, tags, created_at, updated_at)
         VALUES ('s1', 'Test', '1.1.1.1', 22, 'root', 'password', 'UTF-8', '[]', '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();
    conn.execute(
        "INSERT INTO port_forwards (id, server_id, forward_type, local_host, local_port, created_at)
         VALUES ('pf1', 's1', 'local', '127.0.0.1', 8080, '2024-01-01')",
        [],
    ).unwrap();

    // Deleting server should cascade delete port forwards
    conn.execute("DELETE FROM servers WHERE id='s1'", []).unwrap();
    let count: i32 = conn.query_row("SELECT COUNT(*) FROM port_forwards", [], |r| r.get(0)).unwrap();
    assert_eq!(count, 0);
}

// ── Known Hosts ──

#[test]
fn test_known_host_insert() {
    let conn = setup_db();
    conn.execute(
        "INSERT INTO known_hosts (host, port, key_type, fingerprint, first_seen, last_seen)
         VALUES ('example.com', 22, 'ssh-ed25519', 'SHA256:abc123', '2024-01-01', '2024-01-01')",
        [],
    ).unwrap();

    let fp: String = conn.query_row(
        "SELECT fingerprint FROM known_hosts WHERE host='example.com' AND port=22",
        [], |r| r.get(0),
    ).unwrap();
    assert_eq!(fp, "SHA256:abc123");
}
