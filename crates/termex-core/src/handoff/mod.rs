//! Cross-device handoff primitives — device registry, ownership
//! lock, and the wire-level protocol DTOs shared between the daemon
//! and any client SDK (mobile, desktop, automation).
//!
//! v0.74.2 lands the Rust core: data types + SQLite-backed registry
//! and ownership table with race-safe transactions. The WebSocket
//! handlers, FCM relay for offline targets, and Flutter UI layer on
//! top in follow-up changes.

pub mod ownership;
pub mod registry;

use serde::{Deserialize, Serialize};

/// A client device the user has previously connected from. The
/// `id` is generated on first launch and stashed in keychain; users
/// can edit `name`. `push_token` is optional — OSS users without
/// FCM credentials never populate it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Device {
    pub id: String,
    pub name: String,
    pub platform: DevicePlatform,
    pub first_seen_at: String,
    pub last_seen_at: String,
    pub push_token: Option<String>,
    pub push_platform: Option<PushPlatform>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DevicePlatform {
    Ios,
    Android,
    Macos,
    Linux,
    Windows,
}

impl DevicePlatform {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Ios => "ios",
            Self::Android => "android",
            Self::Macos => "macos",
            Self::Linux => "linux",
            Self::Windows => "windows",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "ios" => Some(Self::Ios),
            "android" => Some(Self::Android),
            "macos" => Some(Self::Macos),
            "linux" => Some(Self::Linux),
            "windows" => Some(Self::Windows),
            _ => None,
        }
    }

    /// Mobile devices are the natural targets for push notifications
    /// when offline; desktops typically stay connected, so we don't
    /// fall back to FCM for them.
    pub fn is_mobile(&self) -> bool {
        matches!(self, Self::Ios | Self::Android)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PushPlatform {
    IosApns,
    AndroidFcm,
}

/// Trimmed view used by the watchers list — drops the push token
/// (sensitive) and surfaces only what the UI shows.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeviceSummary {
    pub id: String,
    pub name: String,
    pub platform: DevicePlatform,
    pub last_seen_at: String,
}

impl From<&Device> for DeviceSummary {
    fn from(d: &Device) -> Self {
        Self {
            id: d.id.clone(),
            name: d.name.clone(),
            platform: d.platform,
            last_seen_at: d.last_seen_at.clone(),
        }
    }
}

/// The wire payload sent to a target device when another device
/// invokes `handoff.send`. `from_device` is the trimmed summary
/// (never the push token).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HandoffEnvelope {
    pub task_id: String,
    pub from_device: DeviceSummary,
    pub deep_link: String,
    pub ts_ms: u64,
}

/// How a handoff message reached the target — informs the UI ack
/// ("delivered" vs "queued for when the device wakes up").
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DeliveryPath {
    /// Target was online and connected via WebSocket.
    Ws,
    /// Target was offline; daemon dispatched an FCM push.
    Fcm,
    /// Target was offline and had no push token; queued in daemon
    /// for next connect (up to retention window).
    Queued,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HandoffAck {
    pub delivered: bool,
    pub delivery_path: DeliveryPath,
}

/// Result of a takeover attempt. `Won` means this device is now the
/// owner; `RaceLost` means another takeover landed first and the
/// client should re-fetch ownership before retrying.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TakeoverOutcome {
    Won { previous_owner_id: Option<String> },
    RaceLost { actual_owner_id: Option<String> },
}

/// Error surface for the registry + ownership modules.
#[derive(Debug, thiserror::Error)]
pub enum HandoffError {
    #[error("device not registered: {0}")]
    UnknownDevice(String),
    #[error("ownership changed concurrently; please retry")]
    OwnershipRaceLost,
    #[error("sql: {0}")]
    Sql(#[from] rusqlite::Error),
}
