//! Shared state for the local AI bridge surface.
//!
//! Parallels `termex-tauri`'s `AppState::llama_server` + `active_downloads` but
//! lives as a singleton so FRB async functions can reach it without a handle.

use dashmap::DashMap;
use once_cell::sync::Lazy;
use std::sync::atomic::AtomicBool;
use tokio::sync::{oneshot, RwLock};

use termex_core::local_ai::LlamaServerState;

pub static LLAMA_SERVER: Lazy<RwLock<LlamaServerState>> =
    Lazy::new(|| RwLock::new(LlamaServerState::new()));

pub static ACTIVE_DOWNLOADS: Lazy<DashMap<String, oneshot::Sender<()>>> =
    Lazy::new(DashMap::new);

/// Set to true when the user disables auto-start while it is still pending.
/// The auto-start task polls this flag before spawning llama-server.
pub static AUTO_START_CANCELLED: AtomicBool = AtomicBool::new(false);

/// Catalog entry paired with a HuggingFace download URL + SHA256 hash.
///
/// Keeping this in Rust rather than shipping it through a migration keeps the
/// first-run experience zero-network for users who never open the AI panel.
pub struct ModelCatalogEntry {
    pub id: &'static str,
    pub filename: &'static str,
    pub url: &'static str,
    pub mirror_url: Option<&'static str>,
    pub sha256: &'static str,
}

/// Curated catalog. URLs point to quantized GGUF files on HuggingFace.
/// The SHA256 values are left as placeholder strings — the downloader
/// recognises the `placeholder_` prefix and skips verification. A follow-up
/// ticket replaces them with real digests once the URLs are pinned.
pub const MODEL_CATALOG: &[ModelCatalogEntry] = &[
    ModelCatalogEntry {
        id: "llama3-8b-q4",
        filename: "llama3-8b-q4.gguf",
        url: "https://huggingface.co/bartowski/Meta-Llama-3-8B-Instruct-GGUF/resolve/main/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf",
        mirror_url: Some("https://hf-mirror.com/bartowski/Meta-Llama-3-8B-Instruct-GGUF/resolve/main/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf"),
        sha256: "placeholder_llama3_8b_q4",
    },
    ModelCatalogEntry {
        id: "phi3-mini-q4",
        filename: "phi3-mini-q4.gguf",
        url: "https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf",
        mirror_url: Some("https://hf-mirror.com/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf"),
        sha256: "placeholder_phi3_mini_q4",
    },
    ModelCatalogEntry {
        id: "qwen2-7b-q4",
        filename: "qwen2-7b-q4.gguf",
        url: "https://huggingface.co/bartowski/Qwen2-7B-Instruct-GGUF/resolve/main/Qwen2-7B-Instruct-Q4_K_M.gguf",
        mirror_url: Some("https://hf-mirror.com/bartowski/Qwen2-7B-Instruct-GGUF/resolve/main/Qwen2-7B-Instruct-Q4_K_M.gguf"),
        sha256: "placeholder_qwen2_7b_q4",
    },
];

pub fn catalog_lookup(model_id: &str) -> Option<&'static ModelCatalogEntry> {
    MODEL_CATALOG.iter().find(|e| e.id == model_id)
}
