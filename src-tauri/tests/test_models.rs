use termex_lib::storage::models::{AuthType, ForwardType, ProviderType};

// ── AuthType Tests ──

#[test]
fn test_auth_type_as_str() {
    assert_eq!(AuthType::Password.as_str(), "password");
    assert_eq!(AuthType::Key.as_str(), "key");
}

#[test]
fn test_auth_type_from_str() {
    assert_eq!(AuthType::from_str("password"), Some(AuthType::Password));
    assert_eq!(AuthType::from_str("key"), Some(AuthType::Key));
    assert_eq!(AuthType::from_str("invalid"), None);
    assert_eq!(AuthType::from_str(""), None);
}

#[test]
fn test_auth_type_serialize() {
    let json = serde_json::to_string(&AuthType::Password).unwrap();
    assert_eq!(json, "\"password\"");
    let json = serde_json::to_string(&AuthType::Key).unwrap();
    assert_eq!(json, "\"key\"");
}

#[test]
fn test_auth_type_deserialize() {
    let auth: AuthType = serde_json::from_str("\"password\"").unwrap();
    assert_eq!(auth, AuthType::Password);
    let auth: AuthType = serde_json::from_str("\"key\"").unwrap();
    assert_eq!(auth, AuthType::Key);
}

// ── ForwardType Tests ──

#[test]
fn test_forward_type_as_str() {
    assert_eq!(ForwardType::Local.as_str(), "local");
    assert_eq!(ForwardType::Remote.as_str(), "remote");
    assert_eq!(ForwardType::Dynamic.as_str(), "dynamic");
}

#[test]
fn test_forward_type_from_str() {
    assert_eq!(ForwardType::from_str("local"), ForwardType::Local);
    assert_eq!(ForwardType::from_str("remote"), ForwardType::Remote);
    assert_eq!(ForwardType::from_str("dynamic"), ForwardType::Dynamic);
    // Unknown defaults to Local
    assert_eq!(ForwardType::from_str("unknown"), ForwardType::Local);
    assert_eq!(ForwardType::from_str(""), ForwardType::Local);
}

#[test]
fn test_forward_type_serialize() {
    let json = serde_json::to_string(&ForwardType::Remote).unwrap();
    assert_eq!(json, "\"remote\"");
}

#[test]
fn test_forward_type_deserialize() {
    let ft: ForwardType = serde_json::from_str("\"dynamic\"").unwrap();
    assert_eq!(ft, ForwardType::Dynamic);
}

// ── ProviderType Tests ──

#[test]
fn test_provider_type_as_str_all() {
    assert_eq!(ProviderType::Claude.as_str(), "claude");
    assert_eq!(ProviderType::Openai.as_str(), "openai");
    assert_eq!(ProviderType::Gemini.as_str(), "gemini");
    assert_eq!(ProviderType::Deepseek.as_str(), "deepseek");
    assert_eq!(ProviderType::Ollama.as_str(), "ollama");
    assert_eq!(ProviderType::Grok.as_str(), "grok");
    assert_eq!(ProviderType::Mistral.as_str(), "mistral");
    assert_eq!(ProviderType::Glm.as_str(), "glm");
    assert_eq!(ProviderType::Minimax.as_str(), "minimax");
    assert_eq!(ProviderType::Doubao.as_str(), "doubao");
    assert_eq!(ProviderType::Custom.as_str(), "custom");
}

#[test]
fn test_provider_type_serialize() {
    let json = serde_json::to_string(&ProviderType::Claude).unwrap();
    assert_eq!(json, "\"claude\"");
    let json = serde_json::to_string(&ProviderType::Grok).unwrap();
    assert_eq!(json, "\"grok\"");
}

#[test]
fn test_provider_type_deserialize() {
    let pt: ProviderType = serde_json::from_str("\"gemini\"").unwrap();
    assert_eq!(pt, ProviderType::Gemini);
    let pt: ProviderType = serde_json::from_str("\"ollama\"").unwrap();
    assert_eq!(pt, ProviderType::Ollama);
}

#[test]
fn test_provider_type_roundtrip() {
    for pt in &[
        ProviderType::Claude, ProviderType::Openai, ProviderType::Gemini,
        ProviderType::Deepseek, ProviderType::Ollama, ProviderType::Grok,
        ProviderType::Mistral, ProviderType::Glm, ProviderType::Minimax,
        ProviderType::Doubao, ProviderType::Custom,
    ] {
        let json = serde_json::to_string(pt).unwrap();
        let parsed: ProviderType = serde_json::from_str(&json).unwrap();
        assert_eq!(&parsed, pt);
    }
}
