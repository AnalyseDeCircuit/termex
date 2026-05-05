/// Team permission matrix (v0.46 spec §5.1.5).
///
/// The matrix is keyed by permission key; values are the set of roles that
/// possess the permission.  All writes are checked both client-side (for UX)
/// and in `termex-core::team` before being committed to the database.
use flutter_rust_bridge::frb;

// ─── Roles ───────────────────────────────────────────────────────────────────

pub const ROLE_ADMIN: &str = "admin";
pub const ROLE_DEV: &str = "dev";
pub const ROLE_VIEWER: &str = "viewer";

pub const ALL_ROLES: &[&str] = &[ROLE_ADMIN, ROLE_DEV, ROLE_VIEWER];

// ─── Permission keys ─────────────────────────────────────────────────────────

pub const PERM_SERVER_VIEW: &str = "server.view";
pub const PERM_SERVER_CONNECT: &str = "server.connect";
pub const PERM_SERVER_CREATE: &str = "server.create";
pub const PERM_SERVER_EDIT_META: &str = "server.edit_meta";
pub const PERM_SERVER_EDIT_CREDENTIAL: &str = "server.edit_credential";
pub const PERM_SERVER_DELETE: &str = "server.delete";
pub const PERM_SFTP_ACCESS: &str = "sftp.access";
pub const PERM_SFTP_WRITE: &str = "sftp.write";
pub const PERM_MEMBER_INVITE: &str = "member.invite";
pub const PERM_MEMBER_ROLE_CHANGE: &str = "member.role_change";
pub const PERM_MEMBER_REMOVE: &str = "member.remove";
pub const PERM_SNIPPET_SHARE: &str = "snippet.share";
pub const PERM_AUDIT_VIEW: &str = "audit.view";

pub const ALL_PERMISSIONS: &[&str] = &[
    PERM_SERVER_VIEW,
    PERM_SERVER_CONNECT,
    PERM_SERVER_CREATE,
    PERM_SERVER_EDIT_META,
    PERM_SERVER_EDIT_CREDENTIAL,
    PERM_SERVER_DELETE,
    PERM_SFTP_ACCESS,
    PERM_SFTP_WRITE,
    PERM_MEMBER_INVITE,
    PERM_MEMBER_ROLE_CHANGE,
    PERM_MEMBER_REMOVE,
    PERM_SNIPPET_SHARE,
    PERM_AUDIT_VIEW,
];

// ─── Role → allowed permissions ─────────────────────────────────────────────

const ADMIN_PERMISSIONS: &[&str] = ALL_PERMISSIONS;

const DEV_PERMISSIONS: &[&str] = &[
    PERM_SERVER_VIEW,
    PERM_SERVER_CONNECT,
    PERM_SERVER_CREATE,
    PERM_SERVER_EDIT_META,
    PERM_SFTP_ACCESS,
    PERM_SFTP_WRITE,
    PERM_SNIPPET_SHARE,
];

const VIEWER_PERMISSIONS: &[&str] = &[
    PERM_SERVER_VIEW,
    PERM_SERVER_CONNECT,
];

/// Returns `true` if `role` has the `permission` key.
#[frb]
pub fn team_has_permission(role: String, permission: String) -> bool {
    let set: &[&str] = match role.as_str() {
        ROLE_ADMIN => ADMIN_PERMISSIONS,
        ROLE_DEV => DEV_PERMISSIONS,
        ROLE_VIEWER => VIEWER_PERMISSIONS,
        _ => return false,
    };
    set.contains(&permission.as_str())
}

/// Lists every permission key the given `role` possesses.
#[frb]
pub fn team_role_permissions(role: String) -> Vec<String> {
    let set: &[&str] = match role.as_str() {
        ROLE_ADMIN => ADMIN_PERMISSIONS,
        ROLE_DEV => DEV_PERMISSIONS,
        ROLE_VIEWER => VIEWER_PERMISSIONS,
        _ => return vec![],
    };
    set.iter().map(|s| s.to_string()).collect()
}

/// Lists every permission key defined by the matrix, for UI rendering.
#[frb]
pub fn team_list_permission_keys() -> Vec<String> {
    ALL_PERMISSIONS.iter().map(|s| s.to_string()).collect()
}

/// Lists every role name defined by the matrix.
#[frb]
pub fn team_list_roles() -> Vec<String> {
    ALL_ROLES.iter().map(|s| s.to_string()).collect()
}
