use termex_flutter_bridge::api::theme::{ThemeConfig, get_theme_config, set_theme_config};

#[test]
fn get_theme_config_returns_default_system() {
    let config = get_theme_config().expect("should succeed");
    // Default may be "system" or whatever was last set in this process
    assert!(["light", "dark", "system"].contains(&config.mode.as_str()));
}

#[test]
fn set_theme_config_dark_roundtrip() {
    set_theme_config(ThemeConfig { mode: "dark".to_string(), custom_json: None })
        .expect("set should succeed");
    let config = get_theme_config().expect("get should succeed");
    assert_eq!(config.mode, "dark");
    assert!(config.custom_json.is_none());
    // reset
    set_theme_config(ThemeConfig { mode: "system".to_string(), custom_json: None }).ok();
}

#[test]
fn set_theme_config_invalid_mode_returns_error() {
    let result = set_theme_config(ThemeConfig { mode: "rainbow".to_string(), custom_json: None });
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("invalid theme mode"));
}
