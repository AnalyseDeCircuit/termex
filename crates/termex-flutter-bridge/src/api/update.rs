//! Auto-update check API (v0.49 spec §5).
//!
//! Implements the feed polling side of the three-platform updater.  The
//! Rust side exposes version comparison + appcast/feed URL construction and
//! parses a minimal Sparkle-compatible XML payload.  Platform-specific
//! download + install logic lives in Dart (`app/lib/system/auto_updater_*`).

use once_cell::sync::Lazy;
use std::sync::Mutex;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum UpdateChannel {
    Stable,
    Beta,
    StableLegacy,
}

#[flutter_rust_bridge::frb(ignore)]
impl UpdateChannel {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Stable => "stable",
            Self::Beta => "beta",
            Self::StableLegacy => "stable-legacy",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "stable" => Some(Self::Stable),
            "beta" => Some(Self::Beta),
            "stable-legacy" => Some(Self::StableLegacy),
            _ => None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct UpdateManifest {
    pub current_version: String,
    pub available_version: Option<String>,
    pub changelog_url: Option<String>,
    pub download_url: Option<String>,
    pub delta_from: Option<String>,
    pub delta_url: Option<String>,
    pub size_bytes: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct UpdateConfig {
    pub channel: String,
    pub auto_download: bool,
    pub check_interval_hours: i64,
    pub last_checked_at: Option<String>,
}

impl Default for UpdateConfig {
    fn default() -> Self {
        Self {
            channel: "stable".to_string(),
            auto_download: false,
            check_interval_hours: 24,
            last_checked_at: None,
        }
    }
}

static CONFIG: Lazy<Mutex<UpdateConfig>> = Lazy::new(|| Mutex::new(UpdateConfig::default()));

pub fn appcast_url(channel: &str) -> String {
    format!("https://termex.app/updates/{}/appcast.xml", channel)
}

/// Compare semver `a` vs `b`.  Returns 1 if a>b, -1 if a<b, 0 equal.
///
/// Accepts `"0.49.0"` and `"0.49.0-beta.3"` — pre-release is considered
/// lower than release per semver §11.
pub fn compare_versions(a: &str, b: &str) -> i32 {
    fn split(s: &str) -> (Vec<u32>, Option<String>) {
        let mut pre = None;
        let core = if let Some(idx) = s.find('-') {
            pre = Some(s[idx + 1..].to_string());
            &s[..idx]
        } else {
            s
        };
        let parts = core.split('.').filter_map(|p| p.parse().ok()).collect();
        (parts, pre)
    }
    let (av, ap) = split(a);
    let (bv, bp) = split(b);
    for i in 0..av.len().max(bv.len()) {
        let x = av.get(i).copied().unwrap_or(0);
        let y = bv.get(i).copied().unwrap_or(0);
        if x > y {
            return 1;
        }
        if x < y {
            return -1;
        }
    }
    match (ap, bp) {
        (None, None) => 0,
        (None, Some(_)) => 1,
        (Some(_), None) => -1,
        (Some(x), Some(y)) => x.as_str().cmp(y.as_str()) as i32,
    }
}

pub fn is_update_available(current: &str, remote: &str) -> bool {
    compare_versions(remote, current) > 0
}

/// Parse a minimal Sparkle-style appcast and return the highest release that
/// is newer than `current_version`.
///
/// Only the fields we need are extracted — this is *not* a general-purpose
/// RSS parser.  Tolerates unknown elements.
pub fn parse_appcast(xml: &str, current_version: &str) -> UpdateManifest {
    fn find_tag<'a>(src: &'a str, tag: &str) -> Option<&'a str> {
        let open = format!("<{}>", tag);
        let close = format!("</{}>", tag);
        let start = src.find(&open)? + open.len();
        let end = src[start..].find(&close)? + start;
        Some(src[start..end].trim())
    }
    fn find_attr(src: &str, tag: &str, attr: &str) -> Option<String> {
        let needle = format!("<{} ", tag);
        let start = src.find(&needle)? + needle.len();
        let end_of_tag = src[start..].find('>')? + start;
        let slice = &src[start..end_of_tag];
        let key = format!("{}=\"", attr);
        let k = slice.find(&key)? + key.len();
        let rest = &slice[k..];
        let e = rest.find('"')?;
        Some(rest[..e].to_string())
    }

    let mut manifest = UpdateManifest {
        current_version: current_version.to_string(),
        available_version: None,
        changelog_url: None,
        download_url: None,
        delta_from: None,
        delta_url: None,
        size_bytes: None,
    };

    let mut best: Option<String> = None;
    for item in xml.split("<item>").skip(1) {
        let chunk = item.split("</item>").next().unwrap_or("");
        let version = find_tag(chunk, "sparkle:version")
            .or_else(|| find_tag(chunk, "sparkle:shortVersionString"))
            .map(|s| s.to_string());
        let Some(v) = version else { continue };
        if !is_update_available(current_version, &v) {
            continue;
        }
        if let Some(ref b) = best {
            if compare_versions(&v, b) <= 0 {
                continue;
            }
        }
        best = Some(v.clone());
        manifest.available_version = Some(v);
        manifest.changelog_url = find_tag(chunk, "sparkle:releaseNotesLink").map(|s| s.to_string());
        manifest.download_url = find_attr(chunk, "enclosure", "url");
        manifest.size_bytes = find_attr(chunk, "enclosure", "length").and_then(|s| s.parse().ok());
        if let Some(delta_block) = find_tag(chunk, "sparkle:deltas") {
            manifest.delta_from = find_attr(delta_block, "enclosure", "sparkle:deltaFrom");
            manifest.delta_url = find_attr(delta_block, "enclosure", "url");
        }
    }
    manifest
}

pub fn update_config_get() -> UpdateConfig {
    CONFIG.lock().unwrap().clone()
}

pub fn update_config_set(
    channel: Option<String>,
    auto_download: Option<bool>,
    check_interval_hours: Option<i64>,
) -> Result<UpdateConfig, String> {
    let mut cfg = CONFIG.lock().unwrap();
    if let Some(c) = channel {
        if UpdateChannel::parse(&c).is_none() {
            return Err(format!("unknown channel: {}", c));
        }
        cfg.channel = c;
    }
    if let Some(b) = auto_download {
        cfg.auto_download = b;
    }
    if let Some(h) = check_interval_hours {
        if h <= 0 {
            return Err("check_interval_hours must be positive".to_string());
        }
        cfg.check_interval_hours = h;
    }
    Ok(cfg.clone())
}

pub fn update_mark_checked(now_rfc3339: String) {
    let mut cfg = CONFIG.lock().unwrap();
    cfg.last_checked_at = Some(now_rfc3339);
}

#[doc(hidden)]
pub fn _test_reset() {
    *CONFIG.lock().unwrap() = UpdateConfig::default();
}
