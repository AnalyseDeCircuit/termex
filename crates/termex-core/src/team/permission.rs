use super::types::{Capability, TeamJson};

/// Checks if a member has the specified capability, with optional group-level override.
pub fn check_permission(
    team: &TeamJson,
    username: &str,
    capability: &Capability,
    group_id: Option<&str>,
) -> bool {
    let member = match team.members.iter().find(|m| m.username == username) {
        Some(m) => m,
        None => return false,
    };

    // Check group-level overrides first
    if let Some(gid) = group_id {
        if let Some(overrides) = team.role_overrides.get(username) {
            if let Some(group_caps) = overrides.groups.get(gid) {
                return group_caps.contains(capability);
            }
        }
    }

    // Fall back to role's default capabilities
    let role = match team.roles.get(&member.role) {
        Some(r) => r,
        None => return false,
    };
    role.capabilities.contains(capability)
}

/// Checks if a member has at least one of the given capabilities.
pub fn has_any(
    team: &TeamJson,
    username: &str,
    capabilities: &[Capability],
    group_id: Option<&str>,
) -> bool {
    capabilities.iter().any(|c| check_permission(team, username, c, group_id))
}
