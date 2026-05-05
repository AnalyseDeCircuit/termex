use once_cell::sync::Lazy;
use std::sync::Mutex;

/// Theme configuration for the Termex Flutter app.
#[derive(Debug, Clone)]
pub struct ThemeConfig {
    pub mode: String,
    pub custom_json: Option<String>,
}

static THEME_CONFIG: Lazy<Mutex<ThemeConfig>> = Lazy::new(|| {
    Mutex::new(ThemeConfig { mode: "system".to_string(), custom_json: None })
});

const VALID_MODES: &[&str] = &["light", "dark", "system"];

/// Returns the current theme configuration.
///
/// Defaults to `mode = "system"` on first call.
pub fn get_theme_config() -> Result<ThemeConfig, String> {
    Ok(THEME_CONFIG.lock().map_err(|e| e.to_string())?.clone())
}

/// Persists a new theme configuration in memory.
///
/// Returns `Err` if `config.mode` is not one of `"light"`, `"dark"`, `"system"`.
pub fn set_theme_config(config: ThemeConfig) -> Result<(), String> {
    if !VALID_MODES.contains(&config.mode.as_str()) {
        return Err(format!("invalid theme mode: {}", config.mode));
    }
    *THEME_CONFIG.lock().map_err(|e| e.to_string())? = config;
    Ok(())
}
