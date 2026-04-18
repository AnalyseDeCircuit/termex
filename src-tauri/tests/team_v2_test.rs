use std::collections::HashMap;

use termex_lib::team::permission;
use termex_lib::team::sync::migrate_v1_to_v2;
use termex_lib::team::types::*;

fn make_team(members: Vec<(&str, &str)>) -> TeamJson {
    TeamJson {
        version: 2,
        name: "Test Team".to_string(),
        salt: "aabbccdd".to_string(),
        verify: "dummy".to_string(),
        members: members
            .into_iter()
            .map(|(u, r)| TeamMemberEntry {
                username: u.to_string(),
                role: r.to_string(),
                joined_at: "2026-01-01T00:00:00Z".to_string(),
                device_id: "dev-1".to_string(),
            })
            .collect(),
        settings: TeamSettings::default(),
        roles: default_preset_roles(),
        role_overrides: HashMap::new(),
    }
}

// ── Permission checks ───────────────────────────────────────

#[test]
fn test_permission_admin_has_all() {
    let team = make_team(vec![("alice", "admin")]);
    assert!(permission::check_permission(&team, "alice", &Capability::ServerConnect, None));
    assert!(permission::check_permission(&team, "alice", &Capability::ServerDelete, None));
    assert!(permission::check_permission(&team, "alice", &Capability::TeamRemove, None));
    assert!(permission::check_permission(&team, "alice", &Capability::AuditExport, None));
}

#[test]
fn test_permission_developer_limited() {
    let team = make_team(vec![("bob", "developer")]);
    assert!(permission::check_permission(&team, "bob", &Capability::ServerConnect, None));
    assert!(permission::check_permission(&team, "bob", &Capability::SnippetExecute, None));
    assert!(permission::check_permission(&team, "bob", &Capability::SyncPull, None));
    assert!(!permission::check_permission(&team, "bob", &Capability::ServerEdit, None));
    assert!(!permission::check_permission(&team, "bob", &Capability::ServerDelete, None));
    assert!(!permission::check_permission(&team, "bob", &Capability::ServerViewCredentials, None));
    assert!(!permission::check_permission(&team, "bob", &Capability::SyncPush, None));
}

#[test]
fn test_permission_viewer_minimal() {
    let team = make_team(vec![("carol", "viewer")]);
    assert!(permission::check_permission(&team, "carol", &Capability::SyncPull, None));
    assert!(permission::check_permission(&team, "carol", &Capability::AuditView, None));
    assert!(!permission::check_permission(&team, "carol", &Capability::ServerConnect, None));
    assert!(!permission::check_permission(&team, "carol", &Capability::SnippetExecute, None));
}

#[test]
fn test_permission_ops_role() {
    let team = make_team(vec![("dave", "ops")]);
    assert!(permission::check_permission(&team, "dave", &Capability::ServerConnect, None));
    assert!(permission::check_permission(&team, "dave", &Capability::ServerCreate, None));
    assert!(permission::check_permission(&team, "dave", &Capability::ServerEdit, None));
    assert!(permission::check_permission(&team, "dave", &Capability::ServerViewCredentials, None));
    assert!(permission::check_permission(&team, "dave", &Capability::SyncPush, None));
    assert!(!permission::check_permission(&team, "dave", &Capability::ServerDelete, None));
    assert!(!permission::check_permission(&team, "dave", &Capability::TeamRemove, None));
}

#[test]
fn test_permission_unknown_user() {
    let team = make_team(vec![("alice", "admin")]);
    assert!(!permission::check_permission(&team, "nobody", &Capability::ServerConnect, None));
}

#[test]
fn test_permission_unknown_role() {
    let team = make_team(vec![("bob", "ghost_role")]);
    // ghost_role not in roles map
    assert!(!permission::check_permission(&team, "bob", &Capability::ServerConnect, None));
}

// ── Group overrides ─────────────────────────────────────────

#[test]
fn test_permission_group_override() {
    let mut team = make_team(vec![("bob", "developer")]);
    team.role_overrides.insert(
        "bob".to_string(),
        RoleOverride {
            groups: {
                let mut m = HashMap::new();
                m.insert("staging".to_string(), vec![
                    Capability::ServerConnect,
                    Capability::ServerEdit,
                    Capability::ServerViewCredentials,
                ]);
                m
            },
        },
    );

    // With staging group: has override capabilities
    assert!(permission::check_permission(&team, "bob", &Capability::ServerEdit, Some("staging")));
    assert!(permission::check_permission(&team, "bob", &Capability::ServerViewCredentials, Some("staging")));

    // Without group (or different group): falls back to developer role
    assert!(!permission::check_permission(&team, "bob", &Capability::ServerEdit, None));
    assert!(!permission::check_permission(&team, "bob", &Capability::ServerEdit, Some("production")));
}

#[test]
fn test_permission_group_override_does_not_affect_other_users() {
    let mut team = make_team(vec![("bob", "developer"), ("carol", "developer")]);
    team.role_overrides.insert(
        "bob".to_string(),
        RoleOverride {
            groups: {
                let mut m = HashMap::new();
                m.insert("staging".to_string(), vec![Capability::ServerEdit]);
                m
            },
        },
    );

    assert!(permission::check_permission(&team, "bob", &Capability::ServerEdit, Some("staging")));
    assert!(!permission::check_permission(&team, "carol", &Capability::ServerEdit, Some("staging")));
}

// ── has_any ─────────────────────────────────────────────────

#[test]
fn test_has_any() {
    let team = make_team(vec![("bob", "developer")]);
    assert!(permission::has_any(&team, "bob", &[Capability::ServerConnect, Capability::ServerEdit], None));
    assert!(!permission::has_any(&team, "bob", &[Capability::ServerEdit, Capability::ServerDelete], None));
}

// ── Migration ───────────────────────────────────────────────

#[test]
fn test_migrate_v1_to_v2_role_mapping() {
    let mut team = TeamJson {
        version: 1,
        name: "Old Team".to_string(),
        salt: "aabb".to_string(),
        verify: "dummy".to_string(),
        members: vec![
            TeamMemberEntry {
                username: "alice".to_string(),
                role: "admin".to_string(),
                joined_at: "2026-01-01T00:00:00Z".to_string(),
                device_id: "d1".to_string(),
            },
            TeamMemberEntry {
                username: "bob".to_string(),
                role: "member".to_string(),
                joined_at: "2026-01-02T00:00:00Z".to_string(),
                device_id: "d2".to_string(),
            },
            TeamMemberEntry {
                username: "carol".to_string(),
                role: "readonly".to_string(),
                joined_at: "2026-01-03T00:00:00Z".to_string(),
                device_id: "d3".to_string(),
            },
        ],
        settings: TeamSettings::default(),
        roles: HashMap::new(),
        role_overrides: HashMap::new(),
    };

    let migrated = migrate_v1_to_v2(&mut team);
    assert!(migrated);
    assert_eq!(team.version, 2);
    assert_eq!(team.members[0].role, "admin");
    assert_eq!(team.members[1].role, "ops");
    assert_eq!(team.members[2].role, "viewer");
    assert!(team.roles.contains_key("admin"));
    assert!(team.roles.contains_key("ops"));
    assert!(team.roles.contains_key("developer"));
    assert!(team.roles.contains_key("viewer"));
}

#[test]
fn test_migrate_v2_noop() {
    let mut team = make_team(vec![("alice", "admin")]);
    let migrated = migrate_v1_to_v2(&mut team);
    assert!(!migrated);
}

#[test]
fn test_preset_roles_completeness() {
    let roles = default_preset_roles();
    assert_eq!(roles.len(), 4);
    assert!(roles.contains_key("admin"));
    assert!(roles.contains_key("ops"));
    assert!(roles.contains_key("developer"));
    assert!(roles.contains_key("viewer"));

    let admin = &roles["admin"];
    assert!(admin.capabilities.contains(&Capability::ServerConnect));
    assert!(admin.capabilities.contains(&Capability::TeamRemove));
    assert!(admin.capabilities.contains(&Capability::AuditExport));
}
