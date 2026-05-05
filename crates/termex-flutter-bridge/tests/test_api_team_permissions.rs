//! Tests for the v0.46 team permission matrix (§5.1.5).

use termex_flutter_bridge::api::team_permissions::*;

#[test]
fn test_thirteen_permission_keys_defined() {
    let keys = team_list_permission_keys();
    assert_eq!(keys.len(), 13, "spec §5.1.5 defines 13 permission keys");
}

#[test]
fn test_three_roles_defined() {
    let roles = team_list_roles();
    assert_eq!(roles, vec!["admin", "dev", "viewer"]);
}

#[test]
fn test_admin_has_all_permissions() {
    let perms = team_role_permissions("admin".into());
    assert_eq!(perms.len(), 13);
    for key in team_list_permission_keys() {
        assert!(team_has_permission("admin".into(), key));
    }
}

#[test]
fn test_viewer_is_read_only() {
    assert!(team_has_permission("viewer".into(), "server.view".into()));
    assert!(team_has_permission("viewer".into(), "server.connect".into()));
    assert!(!team_has_permission("viewer".into(), "server.create".into()));
    assert!(!team_has_permission("viewer".into(), "sftp.write".into()));
    assert!(!team_has_permission("viewer".into(), "member.invite".into()));
}

#[test]
fn test_dev_can_edit_meta_not_credential() {
    assert!(team_has_permission("dev".into(), "server.edit_meta".into()));
    assert!(!team_has_permission("dev".into(), "server.edit_credential".into()));
    assert!(!team_has_permission("dev".into(), "server.delete".into()));
    assert!(team_has_permission("dev".into(), "sftp.write".into()));
}

#[test]
fn test_only_admin_can_invite() {
    assert!(team_has_permission("admin".into(), "member.invite".into()));
    assert!(!team_has_permission("dev".into(), "member.invite".into()));
    assert!(!team_has_permission("viewer".into(), "member.invite".into()));
}

#[test]
fn test_unknown_role_returns_no_permissions() {
    assert!(team_role_permissions("unknown".into()).is_empty());
    assert!(!team_has_permission("unknown".into(), "server.view".into()));
}
