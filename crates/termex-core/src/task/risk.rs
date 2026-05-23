//! Pre-execution risk assessment for task prompts.
//!
//! v0.72.1 — runs **server-side in termexd** so a malicious client
//! can't bypass policy. Returns a 4-level classification + the
//! patterns / reasons that triggered it, so the UI can show "AI
//! plans to do X; reasons: Y".
//!
//! Critical patterns always block regardless of user policy
//! (`RiskPolicy::NeverConfirm` still hard-floors at Critical).
//! High patterns are user-tunable.
//!
//! See `docs/iterations/v0.72.1-mobile-safety-guardrails-and-adapters.md` §2.2.

use std::sync::OnceLock;

use regex::Regex;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RiskLevel {
    Low,
    Medium,
    High,
    Critical,
}

impl RiskLevel {
    /// True for any non-Low level — UI uses this to render the
    /// PendingConfirmation banner.
    pub fn requires_attention(&self) -> bool {
        !matches!(self, Self::Low)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RiskAssessment {
    pub level: RiskLevel,
    pub reasons: Vec<String>,
    pub matched_patterns: Vec<String>,
    /// First 120 chars of the prompt (one-line) for UI preview.
    pub preview: String,
}

/// Minimal server descriptor needed by the risk scorer. We don't
/// require the full `ServerDto` so the scorer stays a pure function
/// + easy to test.
#[derive(Debug, Clone, Default)]
pub struct ServerProfile {
    pub tags: Vec<String>,
}

impl ServerProfile {
    pub fn has_tag(&self, t: &str) -> bool {
        let needle = t.to_lowercase();
        self.tags.iter().any(|x| x.to_lowercase() == needle)
    }
}

/// User-facing policy applied at task assignment time.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RiskPolicy {
    /// Default — confirm `High` and `Critical`; auto-run others.
    Auto,
    /// Confirm every task regardless of risk level.
    AlwaysConfirm,
    /// Skip confirmation for everything except `Critical` (which is
    /// always blocked — security floor).
    NeverConfirm,
}

impl Default for RiskPolicy {
    fn default() -> Self {
        Self::Auto
    }
}

impl RiskPolicy {
    /// True iff the given assessment + policy combination should
    /// pause for user confirmation (status → PendingConfirmation).
    pub fn needs_confirmation(&self, level: RiskLevel) -> bool {
        match self {
            Self::AlwaysConfirm => true,
            Self::Auto => matches!(level, RiskLevel::High | RiskLevel::Critical),
            Self::NeverConfirm => matches!(level, RiskLevel::Critical),
        }
    }
}

/// Assess a prompt against a server profile.
pub fn assess(prompt: &str, server: &ServerProfile) -> RiskAssessment {
    let preview = extract_preview(prompt);
    let mut reasons = Vec::new();
    let mut patterns = Vec::new();

    for (pat, why, _) in critical_patterns() {
        if !pat.is_match(prompt) {
            continue;
        }
        // The `rm -rf /...` matcher is intentionally broad; carve out
        // scratch directories (`/tmp`, `/var/tmp`) so cleanup work
        // doesn't trip Critical.
        if (*why).contains("rm -rf") && is_safe_tmp_rm_rf(prompt) {
            continue;
        }
        patterns.push(pat.as_str().to_string());
        reasons.push((*why).to_string());
    }
    if !patterns.is_empty() {
        return RiskAssessment {
            level: RiskLevel::Critical,
            reasons,
            matched_patterns: patterns,
            preview,
        };
    }

    if server.has_tag("prod") || server.has_tag("production") || server.has_tag("live") {
        reasons.push("Server tagged as production".to_string());
    }
    for (pat, why, _) in high_patterns() {
        if pat.is_match(prompt) {
            patterns.push(pat.as_str().to_string());
            reasons.push((*why).to_string());
        }
    }
    if !patterns.is_empty() || !reasons.is_empty() {
        return RiskAssessment {
            level: RiskLevel::High,
            reasons,
            matched_patterns: patterns,
            preview,
        };
    }

    for (pat, why, _) in medium_patterns() {
        if pat.is_match(prompt) {
            patterns.push(pat.as_str().to_string());
            reasons.push((*why).to_string());
        }
    }
    if !patterns.is_empty() {
        return RiskAssessment {
            level: RiskLevel::Medium,
            reasons,
            matched_patterns: patterns,
            preview,
        };
    }

    RiskAssessment {
        level: RiskLevel::Low,
        reasons: Vec::new(),
        matched_patterns: Vec::new(),
        preview,
    }
}

/// True when every `rm -rf /<path>` occurrence in the prompt targets
/// a scratch directory (`/tmp` or `/var/tmp`). Used to defang the
/// broad Critical regex without dropping the warning entirely.
fn is_safe_tmp_rm_rf(prompt: &str) -> bool {
    static RE: OnceLock<Regex> = OnceLock::new();
    let re = RE.get_or_init(|| Regex::new(r"(?i)\brm\s+-rf\s+(/\S+)").unwrap());
    let mut any = false;
    for caps in re.captures_iter(prompt) {
        any = true;
        let path = &caps[1];
        let p = path.trim_end_matches('/');
        if !(p.starts_with("/tmp") || p.starts_with("/var/tmp")) {
            return false;
        }
    }
    any
}

fn extract_preview(prompt: &str) -> String {
    prompt
        .lines()
        .next()
        .unwrap_or("")
        .chars()
        .take(120)
        .collect()
}

// ── Pattern registries ──────────────────────────────────────────────

type PatternEntry = (Regex, &'static str, &'static str);

fn critical_patterns() -> &'static [PatternEntry] {
    static CELL: OnceLock<Vec<PatternEntry>> = OnceLock::new();
    CELL.get_or_init(|| {
        vec![
            // Rust's `regex` crate doesn't support look-around, so we
            // match `rm -rf /<path>` broadly and exclude tmp / var/tmp
            // at the code-side via `is_safe_tmp_rm_rf` below.
            (
                Regex::new(r"(?i)\brm\s+-rf\s+/\S+").unwrap(),
                "rm -rf root paths",
                "critical:rm_rf",
            ),
            (
                Regex::new(r"(?i)\bDROP\s+(TABLE|DATABASE|SCHEMA)\b").unwrap(),
                "destructive SQL DROP",
                "critical:drop",
            ),
            (
                Regex::new(r"(?i)\bDELETE\s+FROM\s+\w+\s+WHERE\s+1\s*=\s*1\b").unwrap(),
                "wildcard SQL delete",
                "critical:wildcard_delete",
            ),
            (
                Regex::new(r"(?i)\bdd\s+if=.*\s+of=/dev/").unwrap(),
                "raw disk write via dd",
                "critical:dd",
            ),
            (
                Regex::new(r"(?i)\bmkfs\.").unwrap(),
                "format filesystem",
                "critical:mkfs",
            ),
            (
                Regex::new(r":\(\)\s*\{\s*:\|").unwrap(),
                "fork bomb pattern",
                "critical:fork_bomb",
            ),
            // Match `chmod 777 /` followed by end-of-line / space —
            // covers raw "chmod 777 /" without firing on
            // `chmod 777 /home/foo`.
            (
                Regex::new(r"(?i)\bchmod\s+777\s+/(\s|$)").unwrap(),
                "world-writable on root",
                "critical:chmod_777_root",
            ),
        ]
    })
}

fn high_patterns() -> &'static [PatternEntry] {
    static CELL: OnceLock<Vec<PatternEntry>> = OnceLock::new();
    CELL.get_or_init(|| {
        vec![
            (
                Regex::new(r"(?i)\bsudo\b").unwrap(),
                "sudo invocation",
                "high:sudo",
            ),
            (
                Regex::new(r"(?i)\bkill\s+-9\b").unwrap(),
                "force-kill (SIGKILL)",
                "high:kill_9",
            ),
            (
                Regex::new(r"(?i)\bsystemctl\s+(stop|restart|disable)\b").unwrap(),
                "service control",
                "high:systemctl",
            ),
            (
                Regex::new(r"(?i)\biptables\s+-F\b").unwrap(),
                "flush firewall rules",
                "high:iptables",
            ),
            (
                Regex::new(r"(?i)\bgit\s+push\s+--force\b").unwrap(),
                "git force-push",
                "high:git_force_push",
            ),
            (
                Regex::new(r"(?i)\bgit\s+reset\s+--hard\s+origin/").unwrap(),
                "git remote-reset main",
                "high:git_reset_remote",
            ),
        ]
    })
}

fn medium_patterns() -> &'static [PatternEntry] {
    static CELL: OnceLock<Vec<PatternEntry>> = OnceLock::new();
    CELL.get_or_init(|| {
        vec![
            (
                Regex::new(r"(?i)\b(UPDATE|INSERT|ALTER)\s+\w+").unwrap(),
                "data-write SQL",
                "medium:sql_write",
            ),
            (
                Regex::new(r"(?i)\bgit\s+(push|merge)\b").unwrap(),
                "git write operation",
                "medium:git_write",
            ),
            (
                Regex::new(r"(?i)\bnpm\s+(install|publish)\b").unwrap(),
                "npm write",
                "medium:npm_write",
            ),
            (
                Regex::new(r"(?i)\bdocker\s+(rm|prune)\b").unwrap(),
                "docker cleanup",
                "medium:docker_cleanup",
            ),
        ]
    })
}
