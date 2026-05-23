//! SQLite-backed device registry used by the daemon to remember
//! every client that has ever connected and to enumerate watchers
//! for the "Send to device" picker.

use rusqlite::{params, Connection, OptionalExtension};

use super::{Device, DevicePlatform, HandoffError, PushPlatform};

const SCHEMA_SQL: &str = r#"
CREATE TABLE IF NOT EXISTS devices (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    platform        TEXT NOT NULL,
    first_seen_at   TEXT NOT NULL,
    last_seen_at    TEXT NOT NULL,
    push_token      TEXT,
    push_platform   TEXT
);
CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON devices(last_seen_at);
"#;

pub fn ensure_schema(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute_batch(SCHEMA_SQL)
}

/// Insert-or-update a device. Preserves `first_seen_at` on update
/// (the column the UI uses for "registered since") and refreshes
/// `last_seen_at`, `name`, `push_token`, `push_platform`.
pub fn upsert(conn: &Connection, d: &Device) -> Result<(), HandoffError> {
    conn.execute(
        "INSERT INTO devices
            (id, name, platform, first_seen_at, last_seen_at, push_token, push_platform)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
         ON CONFLICT(id) DO UPDATE SET
            name          = excluded.name,
            platform      = excluded.platform,
            last_seen_at  = excluded.last_seen_at,
            push_token    = excluded.push_token,
            push_platform = excluded.push_platform",
        params![
            d.id,
            d.name,
            d.platform.as_str(),
            d.first_seen_at,
            d.last_seen_at,
            d.push_token,
            d.push_platform.map(push_platform_str),
        ],
    )?;
    Ok(())
}

/// Bump only the heartbeat column. Cheap; called on every WS frame
/// the daemon receives so the offline-detection logic stays current.
pub fn touch_last_seen(
    conn: &Connection,
    device_id: &str,
    now_rfc3339: &str,
) -> Result<(), HandoffError> {
    let n = conn.execute(
        "UPDATE devices SET last_seen_at = ?2 WHERE id = ?1",
        params![device_id, now_rfc3339],
    )?;
    if n == 0 {
        return Err(HandoffError::UnknownDevice(device_id.to_string()));
    }
    Ok(())
}

pub fn get(conn: &Connection, device_id: &str) -> Result<Option<Device>, HandoffError> {
    let row = conn
        .query_row(
            "SELECT id, name, platform, first_seen_at, last_seen_at, push_token, push_platform
             FROM devices WHERE id = ?1",
            params![device_id],
            row_to_device,
        )
        .optional()?;
    Ok(row)
}

/// All known devices, most-recently-seen first.
pub fn list(conn: &Connection) -> Result<Vec<Device>, HandoffError> {
    let mut stmt = conn.prepare(
        "SELECT id, name, platform, first_seen_at, last_seen_at, push_token, push_platform
         FROM devices ORDER BY last_seen_at DESC",
    )?;
    let rows = stmt.query_map([], row_to_device)?;
    let mut out = Vec::new();
    for r in rows {
        out.push(r?);
    }
    Ok(out)
}

/// Delete a device. Used by the "remove old device" gesture and by
/// the periodic GC sweep.
pub fn delete(conn: &Connection, device_id: &str) -> Result<(), HandoffError> {
    let n = conn.execute("DELETE FROM devices WHERE id = ?1", params![device_id])?;
    if n == 0 {
        return Err(HandoffError::UnknownDevice(device_id.to_string()));
    }
    Ok(())
}

/// Drop devices whose `last_seen_at` is older than `cutoff_rfc3339`.
/// Returns the number of rows removed. Callers pass `cutoff =
/// now - 90 days` per the §八 risk table.
pub fn prune_older_than(
    conn: &Connection,
    cutoff_rfc3339: &str,
) -> Result<usize, HandoffError> {
    let n = conn.execute(
        "DELETE FROM devices WHERE last_seen_at < ?1",
        params![cutoff_rfc3339],
    )?;
    Ok(n)
}

fn row_to_device(row: &rusqlite::Row) -> rusqlite::Result<Device> {
    let platform_str: String = row.get(2)?;
    let platform = DevicePlatform::parse(&platform_str).unwrap_or(DevicePlatform::Linux);
    let push_platform_str: Option<String> = row.get(6)?;
    let push_platform = push_platform_str.as_deref().and_then(parse_push_platform);
    Ok(Device {
        id: row.get(0)?,
        name: row.get(1)?,
        platform,
        first_seen_at: row.get(3)?,
        last_seen_at: row.get(4)?,
        push_token: row.get(5)?,
        push_platform,
    })
}

fn push_platform_str(p: PushPlatform) -> &'static str {
    match p {
        PushPlatform::IosApns => "ios_apns",
        PushPlatform::AndroidFcm => "android_fcm",
    }
}

fn parse_push_platform(s: &str) -> Option<PushPlatform> {
    match s {
        "ios_apns" => Some(PushPlatform::IosApns),
        "android_fcm" => Some(PushPlatform::AndroidFcm),
        _ => None,
    }
}
