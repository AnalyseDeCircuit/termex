/// Placeholder ServerDto until FRB codegen produces the real type.
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
  });

  ServerDto copyWith({
    String? id, String? name, String? host, int? port, String? username,
    String? authType, String? keyPath, String? groupId, int? sortOrder,
    List<String>? tags, String? lastConnected, String? createdAt, String? updatedAt,
  }) {
    return ServerDto(
      id: id ?? this.id, name: name ?? this.name, host: host ?? this.host,
      port: port ?? this.port, username: username ?? this.username,
      authType: authType ?? this.authType, keyPath: keyPath ?? this.keyPath,
      groupId: groupId ?? this.groupId, sortOrder: sortOrder ?? this.sortOrder,
      tags: tags ?? this.tags, lastConnected: lastConnected ?? this.lastConnected,
      createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
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
  final String? keyPath;
  final String? groupId;
  final List<String> tags;

  const ServerInput({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.authType,
    this.password,
    this.keyPath,
    this.groupId,
    required this.tags,
  });
}
