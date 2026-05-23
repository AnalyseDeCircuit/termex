use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::Instant;

/// A device discovered via mDNS on the local network.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscoveredDevice {
    pub id: String,
    pub name: String,
    pub host: Option<String>,
    pub port: u16,
    pub version: String,
}

/// Pairing session created by the receiver (host) device.
/// Contains a 6-digit numeric code the initiator must confirm.
#[derive(Debug, Clone)]
pub struct PairingInfo {
    /// 6-digit numeric code displayed to the user.
    pub code: String,
    /// UUID v4 token used as a handle for this pairing attempt.
    pub token: String,
    /// Monotonic instant when the pairing was created (for expiry checks).
    pub created_at: Instant,
}

impl PairingInfo {
    /// Creates a new pairing with a fresh token.
    /// In test builds the code is always "123456" for determinism.
    pub fn new() -> Self {
        use uuid::Uuid;
        let code = {
            #[cfg(not(test))]
            {
                format!("{:06}", rand_code())
            }
            #[cfg(test)]
            {
                "123456".to_string()
            }
        };
        Self {
            code,
            token: Uuid::new_v4().to_string(),
            created_at: Instant::now(),
        }
    }

    /// Returns `true` when the pairing has been outstanding for more than 3 minutes.
    pub fn is_expired(&self) -> bool {
        self.created_at.elapsed().as_secs() > 180
    }

    /// Returns `true` when `input` matches the code and the pairing has not expired.
    pub fn verify_code(&self, input: &str) -> bool {
        !self.is_expired() && self.code == input
    }
}

impl Default for PairingInfo {
    fn default() -> Self {
        Self::new()
    }
}

/// Returns a pseudo-random 6-digit code (100000–999999) based on sub-second
/// system clock entropy. Not cryptographically strong, but sufficient for a
/// short-lived human-readable confirmation code.
#[cfg(not(test))]
fn rand_code() -> u32 {
    use std::time::{SystemTime, UNIX_EPOCH};
    let ns = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .subsec_nanos();
    100000 + (ns % 900000)
}

/// Full sync payload transmitted between devices.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncPayload {
    pub version: u64,
    pub timestamp: String,
    pub checksum: String,
    pub data: SyncData,
}

/// The data transferred during a sync operation.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SyncData {
    pub servers: Vec<ServerDto>,
    pub groups: Vec<GroupDto>,
    pub proxies: Vec<ProxyDto>,
    pub snippets: Vec<SnippetDto>,
    pub settings: HashMap<String, String>,
    /// Optional encrypted credential bundle — only included when the user
    /// opts in and provides a transfer password.
    pub credentials: Option<EncryptedCredentials>,
}

/// Lightweight server record transferred during sync.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ServerDto {
    pub id: String,
    pub name: String,
    pub host: String,
    pub port: u16,
    pub username: String,
    pub updated_at: String,
    pub sync_version: u64,
}

/// Server group record.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GroupDto {
    pub id: String,
    pub name: String,
    pub updated_at: String,
}

/// Proxy configuration record.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProxyDto {
    pub id: String,
    pub name: String,
    pub proxy_type: String,
    pub host: String,
    pub port: u16,
    pub updated_at: String,
}

/// Command snippet record.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SnippetDto {
    pub id: String,
    pub name: String,
    pub command: String,
    pub updated_at: String,
    pub sync_version: u64,
}

/// AES-256-GCM encrypted credential bundle with embedded KDF parameters.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EncryptedCredentials {
    /// Random 32-byte Argon2id salt generated fresh for each encryption.
    pub kdf_salt: [u8; 32],
    /// KDF parameters used to derive the encryption key from the password.
    pub kdf_params: Argon2Params,
    /// 12-byte AES-GCM nonce.
    pub nonce: [u8; 12],
    /// Ciphertext with appended 16-byte GCM authentication tag.
    pub ciphertext: Vec<u8>,
}

/// Argon2 key-derivation parameters serialised alongside the ciphertext so
/// the receiver can reproduce the key without out-of-band negotiation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Argon2Params {
    pub m_cost_kib: u32,
    pub t_cost: u32,
    pub parallelism: u32,
    pub variant: String,
}

impl Default for Argon2Params {
    fn default() -> Self {
        Self {
            m_cost_kib: 65536,
            t_cost: 3,
            parallelism: 4,
            variant: "argon2id".to_string(),
        }
    }
}

/// Real-time progress update emitted during a sync operation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncProgress {
    pub stage: SyncStage,
    /// 0.0–1.0 completion fraction.
    pub progress: f32,
    pub detail: String,
}

/// Discrete stages of the sync pipeline.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum SyncStage {
    Discovering,
    Pairing,
    Transferring,
    Merging,
    Done,
}

/// Summary returned to the caller after a completed sync.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SyncSummary {
    pub servers_added: u32,
    pub servers_updated: u32,
    pub conflicts_resolved: u32,
    pub credentials_synced: u32,
    pub duration_ms: u64,
}

/// An incoming pairing request received from a peer device.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IncomingPairingRequest {
    pub request_id: String,
    pub device_id: String,
    pub device_name: String,
    pub timestamp: String,
}

/// Payload sent by the initiator to confirm a pairing.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairConfirmRequest {
    pub pairing_code: String,
    pub pairing_token: String,
}
