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

/// Per-model download progress: `(downloaded_bytes, total_bytes)`. The
/// downloader's progress callback writes into this map; the Dart UI
/// polls via [`local_ai_download_progress`] to drive a progress bar.
///
/// Entries are inserted at download start, updated on every byte
/// boundary, and removed on completion or cancellation so a stale
/// row never confuses a subsequent download of the same model.
pub static DOWNLOAD_PROGRESS: Lazy<DashMap<String, (u64, u64)>> =
    Lazy::new(DashMap::new);

/// Set to true when the user disables auto-start while it is still pending.
/// The auto-start task polls this flag before spawning llama-server.
pub static AUTO_START_CANCELLED: AtomicBool = AtomicBool::new(false);

/// Catalog entry paired with a HuggingFace download URL + SHA256 hash.
///
/// Keeping this in Rust rather than shipping it through a migration keeps the
/// first-run experience zero-network for users who never open the AI panel.
///
/// The ids match the Tauri build's `local-models.json` exactly. They are what
/// the downloaded files on disk are named after, so changing one strands the
/// model a user already has.
pub struct ModelCatalogEntry {
    pub id: &'static str,
    pub filename: &'static str,
    pub display_name: &'static str,
    pub description: &'static str,
    pub quantization: &'static str,
    pub tier: &'static str,
    pub size_bytes: u64,
    pub size_label: &'static str,
    pub min_ram_gb: u32,
    pub context_length: u32,
    pub recommended: bool,
    pub url: &'static str,
    pub mirror_url: Option<&'static str>,
    pub sha256: &'static str,
    pub tags: &'static [&'static str],
}

/// Curated catalog, carried over whole from the Tauri build's
/// `src/assets/local-models.json`. The Flutter port had shrunk it to three
/// entries under different ids, which made every model the old product had
/// downloaded invisible here.
///
/// The SHA256 values are left as placeholder strings — the downloader
/// recognises the `placeholder_` prefix and skips verification.
pub const MODEL_CATALOG: &[ModelCatalogEntry] = &[
    ModelCatalogEntry {
        id: "tinyllama-1.1b-q2",
        filename: "tinyllama-1.1b-q2.gguf",
        display_name: "TinyLlama 1.1B (Q2)",
        description: "Minimal footprint — fits machines with very little spare RAM. Tagged micro, lightweight, experimental, test.",
        quantization: "Q2_K_M",
        tier: "micro",
        size_bytes: 193273528,
        size_label: "0.18 GB",
        min_ram_gb: 2,
        context_length: 2048,
        recommended: false,
        url: "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q2_K.gguf",
        mirror_url: None,
        sha256: "placeholder_tinyllama_q2",
        tags: &["micro", "lightweight", "experimental", "test"],
    },
    ModelCatalogEntry {
        id: "qwen2.5-0.5b-q3",
        filename: "qwen2.5-0.5b-q3.gguf",
        display_name: "Qwen2.5 0.5B (Q3)",
        description: "Minimal footprint — fits machines with very little spare RAM. Tagged micro, chinese, bilingual.",
        quantization: "Q3_K_M",
        tier: "micro",
        size_bytes: 161061274,
        size_label: "0.15 GB",
        min_ram_gb: 2,
        context_length: 8192,
        recommended: false,
        url: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q3_k_m.gguf",
        mirror_url: Some("https://modelscope.cn/models/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q3_k_m.gguf"),
        sha256: "placeholder_qwen2.5_0.5b_q3",
        tags: &["micro", "chinese", "bilingual"],
    },
    ModelCatalogEntry {
        id: "phi-2-q2",
        filename: "phi-2-q2.gguf",
        display_name: "Phi-2 2.7B (Q2)",
        description: "Minimal footprint — fits machines with very little spare RAM. Tagged micro, lightweight, english.",
        quantization: "Q2_K_M",
        tier: "micro",
        size_bytes: 171798692,
        size_label: "0.16 GB",
        min_ram_gb: 2,
        context_length: 2048,
        recommended: false,
        url: "https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/phi-2.Q2_K.gguf",
        mirror_url: None,
        sha256: "placeholder_phi2_q2",
        tags: &["micro", "lightweight", "english"],
    },
    ModelCatalogEntry {
        id: "qwen2.5-0.5b-q4",
        filename: "qwen2.5-0.5b-q4.gguf",
        display_name: "Qwen2.5 0.5B",
        description: "Small model for constrained hardware. Tagged small, bilingual, chinese.",
        quantization: "Q4_K_M",
        tier: "small",
        size_bytes: 429496730,
        size_label: "0.40 GB",
        min_ram_gb: 4,
        context_length: 8192,
        recommended: false,
        url: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf",
        mirror_url: Some("https://modelscope.cn/models/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"),
        sha256: "placeholder_qwen2.5_0.5b_q4",
        tags: &["small", "bilingual", "chinese"],
    },
    ModelCatalogEntry {
        id: "phi-3-3b-q3",
        filename: "phi-3-3b-q3.gguf",
        display_name: "Phi-3 3B (Q3)",
        description: "Small model for constrained hardware. Tagged small, lightweight, english.",
        quantization: "Q3_K_M",
        tier: "small",
        size_bytes: 687194767,
        size_label: "0.64 GB",
        min_ram_gb: 4,
        context_length: 4096,
        recommended: false,
        url: "https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q3_k_m.gguf",
        mirror_url: None,
        sha256: "placeholder_phi3_q3",
        tags: &["small", "lightweight", "english"],
    },
    ModelCatalogEntry {
        id: "mobilequwen-0.5b-q4",
        filename: "mobilequwen-0.5b-q4.gguf",
        display_name: "MobileQwen 0.5B",
        description: "Small model for constrained hardware. Tagged small, mobile, chinese, lightweight.",
        quantization: "Q4_K_M",
        tier: "small",
        size_bytes: 375809638,
        size_label: "0.35 GB",
        min_ram_gb: 4,
        context_length: 32768,
        recommended: false,
        url: "https://huggingface.co/Qwen/MobileQwen-0.5B-Chat-GGUF/resolve/main/qwen-0_5b-chat-q4_k_m.gguf",
        mirror_url: Some("https://modelscope.cn/models/Qwen/MobileQwen-0.5B-Chat-GGUF/resolve/main/qwen-0_5b-chat-q4_k_m.gguf"),
        sha256: "placeholder_mobilequwen_q4",
        tags: &["small", "mobile", "chinese", "lightweight"],
    },
    ModelCatalogEntry {
        id: "llama3.2-3b-q4",
        filename: "llama3.2-3b-q4.gguf",
        display_name: "Llama 3.2 3B",
        description: "Balanced size and quality for everyday use. Tagged medium, balanced, english.",
        quantization: "Q4_K_M",
        tier: "medium",
        size_bytes: 2147483648,
        size_label: "2.0 GB",
        min_ram_gb: 8,
        context_length: 131072,
        recommended: false,
        url: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf",
        mirror_url: None,
        sha256: "placeholder_llama3.2_3b",
        tags: &["medium", "balanced", "english"],
    },
    ModelCatalogEntry {
        id: "qwen2.5-3b-q4",
        filename: "qwen2.5-3b-q4.gguf",
        display_name: "Qwen2.5 3B",
        description: "Balanced size and quality for everyday use. Tagged medium, chinese, balanced.",
        quantization: "Q4_K_M",
        tier: "medium",
        size_bytes: 2147483648,
        size_label: "2.0 GB",
        min_ram_gb: 8,
        context_length: 32768,
        recommended: false,
        url: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf",
        mirror_url: Some("https://modelscope.cn/models/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"),
        sha256: "placeholder_qwen2.5_3b",
        tags: &["medium", "chinese", "balanced"],
    },
    ModelCatalogEntry {
        id: "phi-3-3b-q4",
        filename: "phi-3-3b-q4.gguf",
        display_name: "Phi-3 3B",
        description: "Balanced size and quality for everyday use. Tagged medium, balanced, english.",
        quantization: "Q4_K_M",
        tier: "medium",
        size_bytes: 2147483648,
        size_label: "2.0 GB",
        min_ram_gb: 8,
        context_length: 4096,
        recommended: false,
        url: "https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4_k_m.gguf",
        mirror_url: None,
        sha256: "placeholder_phi3_q4",
        tags: &["medium", "balanced", "english"],
    },
    ModelCatalogEntry {
        id: "qwen2.5-7b-q4",
        filename: "qwen2.5-7b-q4.gguf",
        display_name: "Qwen2.5 7B",
        description: "Best quality; needs a well-provisioned machine. Tagged large, recommended, chinese, bilingual, best-quality.",
        quantization: "Q4_K_M",
        tier: "large",
        size_bytes: 5046586573,
        size_label: "4.7 GB",
        min_ram_gb: 16,
        context_length: 32768,
        recommended: true,
        url: "https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf",
        mirror_url: Some("https://modelscope.cn/models/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf"),
        sha256: "placeholder_qwen2.5_7b",
        tags: &["large", "recommended", "chinese", "bilingual", "best-quality"],
    },
    ModelCatalogEntry {
        id: "llama3.3-8b-q4",
        filename: "llama3.3-8b-q4.gguf",
        display_name: "Llama 3.3 8B",
        description: "Best quality; needs a well-provisioned machine. Tagged large, universal, english, long-context.",
        quantization: "Q4_K_M",
        tier: "large",
        size_bytes: 5583457485,
        size_label: "5.2 GB",
        min_ram_gb: 16,
        context_length: 131072,
        recommended: false,
        url: "https://huggingface.co/bartowski/Llama-3.3-70B-Instruct-GGUF/resolve/main/Llama-3.3-8B-Instruct-Q4_K_M.gguf",
        mirror_url: None,
        sha256: "placeholder_llama3.3_8b",
        tags: &["large", "universal", "english", "long-context"],
    },
    ModelCatalogEntry {
        id: "deepseek-7b-q4",
        filename: "deepseek-7b-q4.gguf",
        display_name: "DeepSeek-Coder 7B",
        description: "Best quality; needs a well-provisioned machine. Tagged large, chinese, code, programming.",
        quantization: "Q4_K_M",
        tier: "large",
        size_bytes: 5046586573,
        size_label: "4.7 GB",
        min_ram_gb: 16,
        context_length: 4096,
        recommended: false,
        url: "https://huggingface.co/deepseek-ai/deepseek-coder-7b-instruct-gguf/resolve/main/deepseek-coder-7b-instruct-q4_k_m.gguf",
        mirror_url: None,
        sha256: "placeholder_deepseek_7b",
        tags: &["large", "chinese", "code", "programming"],
    },
];

pub fn catalog_lookup(model_id: &str) -> Option<&'static ModelCatalogEntry> {
    MODEL_CATALOG.iter().find(|e| e.id == model_id)
}

/// Directories a downloaded model may live in, most-preferred first.
///
/// `paths::models_dir()` (`~/.termex/models`) is canonical and is what the
/// Tauri build wrote to. The Flutter port had been reading and writing
/// `data_dir()/models` instead — a different directory — so anything the old
/// product downloaded was invisible, and anything this one downloaded landed
/// somewhere the rest of the codebase does not look. Reads consult both;
/// writes go to the canonical one.
pub fn model_search_dirs() -> Vec<std::path::PathBuf> {
    let canonical = termex_core::paths::models_dir();
    let legacy = termex_core::paths::data_dir().join("models");
    if legacy == canonical {
        vec![canonical]
    } else {
        vec![canonical, legacy]
    }
}

/// Where new downloads are written.
pub fn model_download_dir() -> std::path::PathBuf {
    termex_core::paths::models_dir()
}

/// First existing file named `filename` across [`model_search_dirs`].
pub fn find_model_file(filename: &str) -> Option<std::path::PathBuf> {
    model_search_dirs()
        .into_iter()
        .map(|d| d.join(filename))
        .find(|p| p.is_file())
}

/// Every `.gguf` on disk, as `(id, path, size)`, deduplicated by id with the
/// most-preferred directory winning.
///
/// The Tauri build listed what was actually present rather than probing for
/// catalogue ids, so a model it downloaded under an id this build does not
/// ship still has to be usable.
pub fn scan_downloaded_models() -> Vec<(String, std::path::PathBuf, u64)> {
    let mut out: Vec<(String, std::path::PathBuf, u64)> = Vec::new();
    for dir in model_search_dirs() {
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if !path.is_file() {
                continue;
            }
            let Some(name) = path.file_name().and_then(|n| n.to_str()) else {
                continue;
            };
            let Some(id) = name.strip_suffix(".gguf") else {
                continue;
            };
            if out.iter().any(|(seen, _, _)| seen == id) {
                continue;
            }
            let size = entry.metadata().map(|m| m.len()).unwrap_or(0);
            out.push((id.to_string(), path, size));
        }
    }
    out.sort_by(|a, b| a.0.cmp(&b.0));
    out
}
