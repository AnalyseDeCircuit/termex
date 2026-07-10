/// Dart-side ServerDto — kept in sync with the FRB-generated bridge type
/// in `app/lib/src/frb_generated/api/server.dart`. The shared package
/// can't import from `app/` (path-dep direction is one-way), so this
/// is the canonical model the UI layer uses; converters in the server
/// list provider map back and forth between the two.
class ServerDto {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String authType; // "password" | "key" | "agent" | "interactive"
  final String? keyPath;
  final String? groupId;
  final int sortOrder;
  final List<String> tags;
  final String? lastConnected;
  final String createdAt;
  final String updatedAt;
  // v0.77.0: routing / sharing badges (mirrors the new FRB fields).
  final String? proxyId;
  final bool hasBastion;
  final bool shared;
  final String? teamId;
  // v0.79.67: sync tab (tmux + Git Auto Sync).
  final String tmuxMode; // "disabled" | "auto" | "always"
  final String tmuxCloseAction; // "detach" | "kill"
  final bool gitSyncEnabled;
  final String? gitSyncRemotePath;
  final String? gitSyncLocalPath;
  final String gitSyncMode; // "notify" | "auto_pull"

  const ServerDto({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.authType,
    this.keyPath,
    this.groupId,
    required this.sortOrder,
    required this.tags,
    this.lastConnected,
    required this.createdAt,
    required this.updatedAt,
    this.proxyId,
    this.hasBastion = false,
    this.shared = false,
    this.teamId,
    this.tmuxMode = 'disabled',
    this.tmuxCloseAction = 'detach',
    this.gitSyncEnabled = false,
    this.gitSyncRemotePath,
    this.gitSyncLocalPath,
    this.gitSyncMode = 'notify',
  });

  ServerDto copyWith({
    String? id, String? name, String? host, int? port, String? username,
    String? authType, String? keyPath, String? groupId, int? sortOrder,
    List<String>? tags, String? lastConnected, String? createdAt, String? updatedAt,
    String? proxyId, bool? hasBastion, bool? shared, String? teamId,
    String? tmuxMode, String? tmuxCloseAction,
    bool? gitSyncEnabled, String? gitSyncRemotePath, String? gitSyncLocalPath,
    String? gitSyncMode,
  }) {
    return ServerDto(
      id: id ?? this.id, name: name ?? this.name, host: host ?? this.host,
      port: port ?? this.port, username: username ?? this.username,
      authType: authType ?? this.authType, keyPath: keyPath ?? this.keyPath,
      groupId: groupId ?? this.groupId, sortOrder: sortOrder ?? this.sortOrder,
      tags: tags ?? this.tags, lastConnected: lastConnected ?? this.lastConnected,
      createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
      proxyId: proxyId ?? this.proxyId,
      hasBastion: hasBastion ?? this.hasBastion,
      shared: shared ?? this.shared,
      teamId: teamId ?? this.teamId,
      tmuxMode: tmuxMode ?? this.tmuxMode,
      tmuxCloseAction: tmuxCloseAction ?? this.tmuxCloseAction,
      gitSyncEnabled: gitSyncEnabled ?? this.gitSyncEnabled,
      gitSyncRemotePath: gitSyncRemotePath ?? this.gitSyncRemotePath,
      gitSyncLocalPath: gitSyncLocalPath ?? this.gitSyncLocalPath,
      gitSyncMode: gitSyncMode ?? this.gitSyncMode,
    );
  }
}

class ServerInput {
  final String name;
  final String host;
  final int port;
  final String username;
  final String authType;
  final String? password;
  final String? passphrase;
  final String? keyPath;
  final String? groupId;
  final List<String> tags;
  // v0.79.67: sync tab fields. All optional — pass null to keep the SQL
  // column default (disabled / detach / 0 / notify).
  final String? tmuxMode;
  final String? tmuxCloseAction;
  final bool? gitSyncEnabled;
  final String? gitSyncRemotePath;
  final String? gitSyncLocalPath;
  final String? gitSyncMode;

  const ServerInput({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.authType,
    this.password,
    this.passphrase,
    this.keyPath,
    this.groupId,
    required this.tags,
    this.tmuxMode,
    this.tmuxCloseAction,
    this.gitSyncEnabled,
    this.gitSyncRemotePath,
    this.gitSyncLocalPath,
    this.gitSyncMode,
  });
}
