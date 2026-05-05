/// Team permission matrix (v0.46 spec §5.1.5).
///
/// Pure Dart mirror of `crates/termex-flutter-bridge/src/api/team_permissions.rs`
/// so UI can render the permissions grid without round-tripping through FRB.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Roles ───────────────────────────────────────────────────────────────────

const String kRoleAdmin = 'admin';
const String kRoleDev = 'dev';
const String kRoleViewer = 'viewer';
const List<String> kAllRoles = [kRoleAdmin, kRoleDev, kRoleViewer];

// ─── Permission keys ─────────────────────────────────────────────────────────

const String kPermServerView = 'server.view';
const String kPermServerConnect = 'server.connect';
const String kPermServerCreate = 'server.create';
const String kPermServerEditMeta = 'server.edit_meta';
const String kPermServerEditCredential = 'server.edit_credential';
const String kPermServerDelete = 'server.delete';
const String kPermSftpAccess = 'sftp.access';
const String kPermSftpWrite = 'sftp.write';
const String kPermMemberInvite = 'member.invite';
const String kPermMemberRoleChange = 'member.role_change';
const String kPermMemberRemove = 'member.remove';
const String kPermSnippetShare = 'snippet.share';
const String kPermAuditView = 'audit.view';

const List<String> kAllPermissions = [
  kPermServerView,
  kPermServerConnect,
  kPermServerCreate,
  kPermServerEditMeta,
  kPermServerEditCredential,
  kPermServerDelete,
  kPermSftpAccess,
  kPermSftpWrite,
  kPermMemberInvite,
  kPermMemberRoleChange,
  kPermMemberRemove,
  kPermSnippetShare,
  kPermAuditView,
];

const List<String> _devPermissions = [
  kPermServerView,
  kPermServerConnect,
  kPermServerCreate,
  kPermServerEditMeta,
  kPermSftpAccess,
  kPermSftpWrite,
  kPermSnippetShare,
];

const List<String> _viewerPermissions = [
  kPermServerView,
  kPermServerConnect,
];

bool teamHasPermission(String role, String permission) {
  switch (role) {
    case kRoleAdmin:
      return kAllPermissions.contains(permission);
    case kRoleDev:
      return _devPermissions.contains(permission);
    case kRoleViewer:
      return _viewerPermissions.contains(permission);
    default:
      return false;
  }
}

List<String> teamRolePermissions(String role) {
  switch (role) {
    case kRoleAdmin:
      return List.unmodifiable(kAllPermissions);
    case kRoleDev:
      return List.unmodifiable(_devPermissions);
    case kRoleViewer:
      return List.unmodifiable(_viewerPermissions);
    default:
      return const [];
  }
}

// ─── State ───────────────────────────────────────────────────────────────────

class TeamPermissionState {
  /// The role of the signed-in user; used to hide/disable UI controls.
  final String myRole;

  const TeamPermissionState({this.myRole = kRoleViewer});

  bool canI(String permission) => teamHasPermission(myRole, permission);

  TeamPermissionState copyWith({String? myRole}) =>
      TeamPermissionState(myRole: myRole ?? this.myRole);
}

class TeamPermissionNotifier extends Notifier<TeamPermissionState> {
  @override
  TeamPermissionState build() => const TeamPermissionState();

  void setRole(String role) {
    if (!kAllRoles.contains(role)) return;
    state = state.copyWith(myRole: role);
  }
}

final teamPermissionProvider =
    NotifierProvider<TeamPermissionNotifier, TeamPermissionState>(
        TeamPermissionNotifier.new);
