use std::sync::Mutex;
use termex_flutter_bridge::api::update::{
    _test_reset, appcast_url, compare_versions, is_update_available, parse_appcast,
    update_config_get, update_config_set, update_mark_checked, UpdateChannel,
};

static TEST_LOCK: Mutex<()> = Mutex::new(());

fn setup() -> std::sync::MutexGuard<'static, ()> {
    let guard = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    _test_reset();
    guard
}

#[test]
fn channel_parse_and_str() {
    assert_eq!(UpdateChannel::parse("stable"), Some(UpdateChannel::Stable));
    assert_eq!(UpdateChannel::parse("beta"), Some(UpdateChannel::Beta));
    assert_eq!(
        UpdateChannel::parse("stable-legacy"),
        Some(UpdateChannel::StableLegacy)
    );
    assert_eq!(UpdateChannel::parse("nightly"), None);
    assert_eq!(UpdateChannel::Stable.as_str(), "stable");
    assert_eq!(UpdateChannel::StableLegacy.as_str(), "stable-legacy");
}

#[test]
fn appcast_url_contains_channel() {
    let url = appcast_url("stable");
    assert!(url.contains("/stable/"));
    assert!(url.ends_with("appcast.xml"));
}

#[test]
fn compare_versions_basic() {
    assert_eq!(compare_versions("0.49.0", "0.48.9"), 1);
    assert_eq!(compare_versions("0.48.9", "0.49.0"), -1);
    assert_eq!(compare_versions("1.0.0", "1.0.0"), 0);
    assert_eq!(compare_versions("0.49.1", "0.49.0"), 1);
    assert_eq!(compare_versions("1.0.0", "0.99.99"), 1);
}

#[test]
fn compare_versions_prerelease() {
    // Pre-release is less than release (semver §11)
    assert_eq!(compare_versions("0.49.0-beta.1", "0.49.0"), -1);
    assert_eq!(compare_versions("0.49.0", "0.49.0-beta.1"), 1);
    assert_eq!(compare_versions("0.49.0-beta.2", "0.49.0-beta.1"), 1);
}

#[test]
fn is_update_available_simple() {
    assert!(is_update_available("0.48.0", "0.49.0"));
    assert!(!is_update_available("0.49.0", "0.49.0"));
    assert!(!is_update_available("0.49.0", "0.48.0"));
}

#[test]
fn parse_appcast_basic() {
    let xml = r#"<rss>
      <channel>
        <item>
          <sparkle:version>0.49.0</sparkle:version>
          <sparkle:releaseNotesLink>https://termex.app/releases/0.49.0</sparkle:releaseNotesLink>
          <enclosure url="https://termex.app/dl/Termex-0.49.0.dmg" length="45678901" type="application/x-apple-diskimage"/>
        </item>
      </channel>
    </rss>"#;
    let m = parse_appcast(xml, "0.48.0");
    assert_eq!(m.available_version.as_deref(), Some("0.49.0"));
    assert_eq!(
        m.download_url.as_deref(),
        Some("https://termex.app/dl/Termex-0.49.0.dmg")
    );
    assert_eq!(m.size_bytes, Some(45_678_901));
    assert_eq!(
        m.changelog_url.as_deref(),
        Some("https://termex.app/releases/0.49.0")
    );
}

#[test]
fn parse_appcast_no_update_when_current_is_newer() {
    let xml = r#"<rss><channel><item>
      <sparkle:version>0.48.0</sparkle:version>
      <enclosure url="u" length="1"/>
    </item></channel></rss>"#;
    let m = parse_appcast(xml, "0.49.0");
    assert!(m.available_version.is_none());
    assert!(m.download_url.is_none());
}

#[test]
fn parse_appcast_picks_highest() {
    let xml = r#"<rss><channel>
      <item><sparkle:version>0.49.0</sparkle:version><enclosure url="a" length="1"/></item>
      <item><sparkle:version>0.49.2</sparkle:version><enclosure url="b" length="1"/></item>
      <item><sparkle:version>0.49.1</sparkle:version><enclosure url="c" length="1"/></item>
    </channel></rss>"#;
    let m = parse_appcast(xml, "0.48.0");
    assert_eq!(m.available_version.as_deref(), Some("0.49.2"));
    assert_eq!(m.download_url.as_deref(), Some("b"));
}

#[test]
fn parse_appcast_delta_info() {
    let xml = r#"<rss><channel><item>
      <sparkle:version>0.49.0</sparkle:version>
      <enclosure url="full" length="10000"/>
      <sparkle:deltas>
        <enclosure url="delta-from-048" sparkle:deltaFrom="0.48.0" length="1000"/>
      </sparkle:deltas>
    </item></channel></rss>"#;
    let m = parse_appcast(xml, "0.48.0");
    assert_eq!(m.delta_from.as_deref(), Some("0.48.0"));
    assert_eq!(m.delta_url.as_deref(), Some("delta-from-048"));
}

#[test]
fn config_defaults() {
    let _lock = setup();
    let cfg = update_config_get();
    assert_eq!(cfg.channel, "stable");
    assert!(!cfg.auto_download);
    assert_eq!(cfg.check_interval_hours, 24);
    assert!(cfg.last_checked_at.is_none());
}

#[test]
fn config_set_channel() {
    let _lock = setup();
    let cfg = update_config_set(Some("beta".into()), None, None).unwrap();
    assert_eq!(cfg.channel, "beta");
}

#[test]
fn config_set_rejects_unknown_channel() {
    let _lock = setup();
    let err = update_config_set(Some("nightly".into()), None, None).unwrap_err();
    assert!(err.contains("unknown channel"));
}

#[test]
fn config_set_rejects_nonpositive_interval() {
    let _lock = setup();
    assert!(update_config_set(None, None, Some(0)).is_err());
    assert!(update_config_set(None, None, Some(-1)).is_err());
}

#[test]
fn config_set_toggle_auto_download() {
    let _lock = setup();
    let cfg = update_config_set(None, Some(true), None).unwrap();
    assert!(cfg.auto_download);
    let cfg = update_config_set(None, Some(false), None).unwrap();
    assert!(!cfg.auto_download);
}

#[test]
fn mark_checked_updates_timestamp() {
    let _lock = setup();
    update_mark_checked("2026-10-10T12:00:00Z".into());
    let cfg = update_config_get();
    assert_eq!(cfg.last_checked_at.as_deref(), Some("2026-10-10T12:00:00Z"));
}
