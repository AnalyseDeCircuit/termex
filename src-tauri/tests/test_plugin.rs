use termex_lib::plugin::manifest::{PluginManifest, PluginPermission};
use termex_lib::plugin::registry::{PluginState, InstalledPlugin, PluginRegistry};

// ── Manifest Parsing Tests ──

#[test]
fn test_parse_valid_manifest() {
    let json = r#"{
        "id": "snippet-manager",
        "name": "Snippet Manager",
        "version": "1.0.0",
        "description": "Manage command snippets",
        "author": "Termex",
        "permissions": ["terminal_write", "storage"],
        "entry": "index.js"
    }"#;
    let manifest = PluginManifest::parse(json).unwrap();
    assert_eq!(manifest.id, "snippet-manager");
    assert_eq!(manifest.permissions.len(), 2);
    assert!(manifest.permissions.contains(&PluginPermission::TerminalWrite));
    assert!(manifest.permissions.contains(&PluginPermission::Storage));
}

#[test]
fn test_parse_minimal_manifest() {
    let json = r#"{
        "id": "test",
        "name": "Test",
        "version": "0.1.0",
        "description": "Test plugin",
        "entry": "main.js"
    }"#;
    let manifest = PluginManifest::parse(json).unwrap();
    assert_eq!(manifest.id, "test");
    assert!(manifest.permissions.is_empty());
    assert!(manifest.author.is_none());
    assert!(manifest.homepage.is_none());
    assert!(manifest.min_termex_version.is_none());
}

#[test]
fn test_parse_missing_id() {
    let json = r#"{
        "id": "",
        "name": "Test",
        "version": "0.1.0",
        "description": "Test",
        "entry": "main.js"
    }"#;
    assert!(PluginManifest::parse(json).is_err());
}

#[test]
fn test_parse_invalid_json() {
    assert!(PluginManifest::parse("not json").is_err());
}

#[test]
fn test_parse_missing_required_fields() {
    let json = r#"{ "id": "test" }"#;
    assert!(PluginManifest::parse(json).is_err());
}

#[test]
fn test_parse_all_permissions() {
    let json = r#"{
        "id": "full",
        "name": "Full",
        "version": "1.0.0",
        "description": "All permissions",
        "entry": "main.js",
        "permissions": ["terminal_read", "terminal_write", "server_info", "network", "storage"]
    }"#;
    let manifest = PluginManifest::parse(json).unwrap();
    assert_eq!(manifest.permissions.len(), 5);
}

#[test]
fn test_permission_serialize() {
    let perm = PluginPermission::TerminalRead;
    let json = serde_json::to_string(&perm).unwrap();
    assert_eq!(json, "\"terminal_read\"");
}

// ── Registry Tests ──

#[test]
fn test_plugin_state_serialize() {
    let json = serde_json::to_string(&PluginState::Enabled).unwrap();
    assert_eq!(json, "\"enabled\"");
    let json = serde_json::to_string(&PluginState::Disabled).unwrap();
    assert_eq!(json, "\"disabled\"");
}

#[test]
fn test_installed_plugin_serialize() {
    let plugin = InstalledPlugin {
        manifest: PluginManifest {
            id: "test".into(),
            name: "Test Plugin".into(),
            version: "1.0.0".into(),
            description: "A test plugin".into(),
            author: None,
            homepage: None,
            permissions: vec![],
            entry: "index.js".into(),
            min_termex_version: None,
        },
        state: PluginState::Enabled,
        install_path: "/tmp/plugins/test".into(),
    };
    let json = serde_json::to_string(&plugin).unwrap();
    assert!(json.contains("\"id\":\"test\""));
    assert!(json.contains("\"state\":\"enabled\""));
    assert!(json.contains("\"installPath\":\"/tmp/plugins/test\""));
}

#[test]
fn test_registry_new_empty() {
    let registry = PluginRegistry::new_empty();
    assert!(registry.list().is_empty());
}

#[test]
fn test_registry_enable_disable_nonexistent() {
    let mut registry = PluginRegistry::new_empty();
    assert!(registry.enable("nonexistent").is_err());
    assert!(registry.disable("nonexistent").is_err());
}

#[test]
fn test_registry_uninstall_nonexistent() {
    let mut registry = PluginRegistry::new_empty();
    assert!(registry.uninstall("nonexistent").is_err());
}

#[test]
fn test_registry_install_from_temp_dir() {
    let dir = std::env::temp_dir().join("termex-test-plugin-install");
    let _ = std::fs::create_dir_all(&dir);
    std::fs::write(
        dir.join("plugin.json"),
        r#"{
            "id": "test-install",
            "name": "Test Install",
            "version": "0.1.0",
            "description": "Test",
            "entry": "main.js"
        }"#,
    ).unwrap();
    std::fs::write(dir.join("main.js"), "// plugin code").unwrap();

    let mut registry = PluginRegistry::new_empty();
    let plugin = registry.install(dir.to_str().unwrap()).unwrap();
    assert_eq!(plugin.manifest.id, "test-install");
    assert_eq!(plugin.state, PluginState::Enabled);
    assert_eq!(registry.list().len(), 1);

    // Duplicate install should fail
    assert!(registry.install(dir.to_str().unwrap()).is_err());

    // Cleanup
    let _ = std::fs::remove_dir_all(&dir);
}
