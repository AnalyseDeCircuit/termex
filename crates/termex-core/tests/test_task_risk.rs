//! Tests for the v0.72.1 risk scorer.

use termex_core::task::risk::{assess, RiskLevel, RiskPolicy, ServerProfile};

fn prod_server() -> ServerProfile {
    ServerProfile {
        tags: vec!["prod".into()],
    }
}

fn dev_server() -> ServerProfile {
    ServerProfile {
        tags: vec!["dev".into()],
    }
}

#[test]
fn assess_low_for_innocuous_prompt() {
    let r = assess("list files in /tmp", &dev_server());
    assert_eq!(r.level, RiskLevel::Low);
    assert!(r.reasons.is_empty());
    assert!(r.matched_patterns.is_empty());
}

#[test]
fn assess_critical_rm_rf_root() {
    let r = assess("please run rm -rf /home/user/build now", &dev_server());
    assert_eq!(r.level, RiskLevel::Critical);
    assert!(r.reasons.iter().any(|x| x.contains("rm -rf")));
}

#[test]
fn assess_critical_drop_table() {
    let r = assess("DROP TABLE users; -- cleanup", &dev_server());
    assert_eq!(r.level, RiskLevel::Critical);
}

#[test]
fn assess_critical_wildcard_delete() {
    let r = assess("DELETE FROM users WHERE 1=1", &dev_server());
    assert_eq!(r.level, RiskLevel::Critical);
}

#[test]
fn assess_critical_fork_bomb() {
    let r = assess(":(){ :|:& };:", &dev_server());
    assert_eq!(r.level, RiskLevel::Critical);
}

#[test]
fn assess_high_sudo() {
    let r = assess("sudo systemctl restart nginx", &dev_server());
    assert_eq!(r.level, RiskLevel::High);
    assert!(r.reasons.iter().any(|x| x.contains("sudo")));
}

#[test]
fn assess_high_kill_9() {
    let r = assess("kill -9 12345", &dev_server());
    assert_eq!(r.level, RiskLevel::High);
}

#[test]
fn assess_high_git_force_push() {
    let r = assess("git push --force origin main", &dev_server());
    assert_eq!(r.level, RiskLevel::High);
}

#[test]
fn assess_high_production_tag() {
    let r = assess("ls /home", &prod_server());
    assert_eq!(r.level, RiskLevel::High);
    assert!(r.reasons.iter().any(|x| x.contains("production")));
}

#[test]
fn assess_medium_sql_update() {
    let r = assess("UPDATE users SET active = 0 WHERE id = 1", &dev_server());
    assert_eq!(r.level, RiskLevel::Medium);
}

#[test]
fn assess_medium_git_push() {
    let r = assess("git push origin feature/abc", &dev_server());
    assert_eq!(r.level, RiskLevel::Medium);
}

#[test]
fn preview_truncates_long_prompts() {
    let long = "a".repeat(500);
    let r = assess(&long, &dev_server());
    assert!(r.preview.chars().count() <= 120);
}

#[test]
fn preview_takes_first_line_only() {
    let r = assess("first line\nsecond line\nthird line", &dev_server());
    assert_eq!(r.preview, "first line");
}

#[test]
fn risk_policy_auto_pauses_on_high_and_critical() {
    assert!(RiskPolicy::Auto.needs_confirmation(RiskLevel::Critical));
    assert!(RiskPolicy::Auto.needs_confirmation(RiskLevel::High));
    assert!(!RiskPolicy::Auto.needs_confirmation(RiskLevel::Medium));
    assert!(!RiskPolicy::Auto.needs_confirmation(RiskLevel::Low));
}

#[test]
fn risk_policy_always_pauses_for_everything() {
    for lvl in [RiskLevel::Low, RiskLevel::Medium, RiskLevel::High, RiskLevel::Critical] {
        assert!(RiskPolicy::AlwaysConfirm.needs_confirmation(lvl));
    }
}

#[test]
fn risk_policy_never_still_blocks_critical_hard_floor() {
    assert!(RiskPolicy::NeverConfirm.needs_confirmation(RiskLevel::Critical));
    assert!(!RiskPolicy::NeverConfirm.needs_confirmation(RiskLevel::High));
    assert!(!RiskPolicy::NeverConfirm.needs_confirmation(RiskLevel::Medium));
    assert!(!RiskPolicy::NeverConfirm.needs_confirmation(RiskLevel::Low));
}

#[test]
fn risk_level_requires_attention() {
    assert!(!RiskLevel::Low.requires_attention());
    assert!(RiskLevel::Medium.requires_attention());
    assert!(RiskLevel::High.requires_attention());
    assert!(RiskLevel::Critical.requires_attention());
}

#[test]
fn server_profile_has_tag_case_insensitive() {
    let s = ServerProfile {
        tags: vec!["Prod".into(), "us-east".into()],
    };
    assert!(s.has_tag("prod"));
    assert!(s.has_tag("PROD"));
    assert!(s.has_tag("us-east"));
    assert!(!s.has_tag("staging"));
}

#[test]
fn assess_excludes_tmp_paths_from_rm_rf_critical() {
    // `/tmp/...` and `/var/tmp/...` are explicitly carved out so
    // running cleanup in scratch directories doesn't trip Critical.
    let r = assess("rm -rf /tmp/cache", &dev_server());
    assert_ne!(r.level, RiskLevel::Critical);
}
