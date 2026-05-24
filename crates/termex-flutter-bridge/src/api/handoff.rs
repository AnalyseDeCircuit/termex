//! FRB bridge for the v0.74.2 cross-device handoff data layer.
//!
//! Only the registry primitives are exposed here — relay /
//! ownership swap go through `api/daemon.rs` once the termexd-side
//! WS handlers land. The client side uses this to render the
//! "Send to device" picker and the "Other watcher" list.

use serde::{Deserialize, Serialize};

use termex_core::handoff::registry as reg;
use termex_core::handoff::{Device, DevicePlatform, PushPlatform};

use crate::db_state;

/// Lazily ensure the `devices` table exists. The handoff registry
/// lives on the daemon side per spec; client-side this acts as a
/// local cache of devices the user has seen, so we materialize the
/// schema on first use rather than reserving a migration slot in
/// the client-side migration chain.
fn ensure_schema(conn: &rusqlite::Connection) -> Result<(), rusqlite::Error> {
    reg::ensure_schema(conn)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeviceDto {
    pub id: String,
    pub name: String,
    /// "ios" / "android" / "macos" / "linux" / "windows".
    pub platform: String,
    pub first_seen_at: String,
    pub last_seen_at: String,
    /// Push token kept opaque to the Dart side — never log.
    pub push_token: Option<String>,
    /// "ios_apns" / "android_fcm" or null.
    pub push_platform: Option<String>,
}

impl From<Device> for DeviceDto {
    fn from(d: Device) -> Self {
        Self {
            id: d.id,
            name: d.name,
            platform: d.platform.as_str().to_string(),
            first_seen_at: d.first_seen_at,
            last_seen_at: d.last_seen_at,
            push_token: d.push_token,
            push_platform: d.push_platform.map(push_platform_str).map(str::to_string),
        }
    }
}

/// Upsert a device — used by the mobile shell's "register on
/// connect" path and the settings page's "rename this device".
pub fn handoff_upsert_device(dto: DeviceDto) -> Result<(), String> {
    let d = dto_to_device(dto)?;
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            ensure_schema(conn)?;
            reg::upsert(conn, &d).map_err(sql_box)?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Heartbeat — refreshes only `last_seen_at`. Cheap; called
/// per-frame by the daemon client.
pub fn handoff_touch_device(device_id: String, now_rfc3339: String) -> Result<(), String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            ensure_schema(conn)?;
            reg::touch_last_seen(conn, &device_id, &now_rfc3339).map_err(sql_box)?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

pub fn handoff_get_device(device_id: String) -> Result<Option<DeviceDto>, String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            ensure_schema(conn)?;
            let d = reg::get(conn, &device_id).map_err(sql_box)?;
            Ok(d.map(Into::into))
        })
        .map_err(|e| e.to_string())
    })
}

/// All known devices, most-recently-seen first. UI maps to
/// DeviceSummaryDto when rendering watcher chips.
pub fn handoff_list_devices() -> Result<Vec<DeviceDto>, String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            ensure_schema(conn)?;
            let v = reg::list(conn).map_err(sql_box)?;
            Ok(v.into_iter().map(Into::into).collect())
        })
        .map_err(|e| e.to_string())
    })
}

pub fn handoff_delete_device(device_id: String) -> Result<(), String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            ensure_schema(conn)?;
            reg::delete(conn, &device_id).map_err(sql_box)?;
            Ok(())
        })
        .map_err(|e| e.to_string())
    })
}

/// Drop devices not seen since `cutoff_rfc3339` (typ. now - 90d).
/// Returns the row count removed.
pub fn handoff_prune_stale(cutoff_rfc3339: String) -> Result<u32, String> {
    db_state::with_db(|db| {
        db.with_conn(|conn| {
            ensure_schema(conn)?;
            let n = reg::prune_older_than(conn, &cutoff_rfc3339).map_err(sql_box)?;
            Ok(n as u32)
        })
        .map_err(|e| e.to_string())
    })
}

fn dto_to_device(dto: DeviceDto) -> Result<Device, String> {
    let platform = DevicePlatform::parse(&dto.platform)
        .ok_or_else(|| format!("unknown platform: {}", dto.platform))?;
    let push_platform = match dto.push_platform.as_deref() {
        None => None,
        Some("ios_apns") => Some(PushPlatform::IosApns),
        Some("android_fcm") => Some(PushPlatform::AndroidFcm),
        Some(other) => return Err(format!("unknown push platform: {other}")),
    };
    Ok(Device {
        id: dto.id,
        name: dto.name,
        platform,
        first_seen_at: dto.first_seen_at,
        last_seen_at: dto.last_seen_at,
        push_token: dto.push_token,
        push_platform,
    })
}

fn push_platform_str(p: PushPlatform) -> &'static str {
    match p {
        PushPlatform::IosApns => "ios_apns",
        PushPlatform::AndroidFcm => "android_fcm",
    }
}

fn sql_box(e: termex_core::handoff::HandoffError) -> rusqlite::Error {
    rusqlite::Error::ToSqlConversionFailure(Box::new(std::io::Error::other(e.to_string())))
}
