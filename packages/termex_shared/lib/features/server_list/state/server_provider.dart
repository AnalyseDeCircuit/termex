import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/api.dart' as frb;

import '../models/server_dto.dart';

// ─── Bridge ↔ local model adapters ───────────────────────────────────────────

ServerDto _fromFrb(frb.ServerDto s) => ServerDto(
      id: s.id,
      name: s.name,
      host: s.host,
      port: s.port,
      username: s.username,
      authType: _authTypeToString(s.authType),
      keyPath: s.keyPath,
      groupId: s.groupId,
      sortOrder: s.sortOrder,
      tags: s.tags,
      lastConnected: s.lastConnected,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
      // v0.77.0: surfaced routing / sharing flags for sidebar badges.
      proxyId: s.proxyId,
      hasBastion: s.hasBastion,
      shared: s.shared,
      teamId: s.teamId,
      // v0.79.67: sync tab fields.
      tmuxMode: s.tmuxMode,
      tmuxCloseAction: s.tmuxCloseAction,
      gitSyncEnabled: s.gitSyncEnabled,
      gitSyncRemotePath: s.gitSyncRemotePath,
      gitSyncLocalPath: s.gitSyncLocalPath,
      gitSyncMode: s.gitSyncMode,
    );

String _authTypeToString(frb.AuthType t) => switch (t) {
      frb.AuthType.password => 'password',
      frb.AuthType.key => 'key',
      frb.AuthType.agent => 'agent',
      frb.AuthType.interactive => 'interactive',
    };

frb.AuthType _authTypeFromString(String s) => switch (s) {
      'password' => frb.AuthType.password,
      'key' => frb.AuthType.key,
      'agent' => frb.AuthType.agent,
      'interactive' => frb.AuthType.interactive,
      _ => frb.AuthType.password,
    };

frb.ServerInput _toFrbInput(ServerInput i) => frb.ServerInput(
      name: i.name,
      host: i.host,
      port: i.port,
      username: i.username,
      authType: _authTypeFromString(i.authType),
      password: i.password,
      passphrase: i.passphrase,
      keyPath: i.keyPath,
      groupId: i.groupId,
      tags: i.tags,
      tmuxMode: i.tmuxMode,
      tmuxCloseAction: i.tmuxCloseAction,
      gitSyncEnabled: i.gitSyncEnabled,
      gitSyncRemotePath: i.gitSyncRemotePath,
      gitSyncLocalPath: i.gitSyncLocalPath,
      gitSyncMode: i.gitSyncMode,
    );

// ─── Bridge calls ───────────────────────────────────────────────────────────

Future<List<ServerDto>> listServers() async {
  final raw = await frb.listServers();
  return raw.map(_fromFrb).toList();
}

Future<String> createServerBridge(ServerInput input) async {
  final created = await frb.createServer(input: _toFrbInput(input));
  return created.id;
}

Future<void> updateServerBridge(String id, ServerInput input) async {
  await frb.updateServer(id: id, input: _toFrbInput(input));
}

Future<void> deleteServerBridge(String id) async {
  await frb.deleteServer(id: id);
}

Future<void> moveServerToGroup({
  required String id,
  required String? groupId,
}) async {
  await frb.moveServerToGroup(id: id, groupId: groupId);
}

Future<void> updateLastConnectedBridge(String id) async {
  await frb.updateLastConnected(id: id);
}

/// Notifier for the full server list.
class ServerListNotifier extends AsyncNotifier<List<ServerDto>> {
  @override
  Future<List<ServerDto>> build() => _fetchAll();

  Future<List<ServerDto>> _fetchAll() async {
    return await listServers();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchAll);
  }

  Future<String> createServer(ServerInput input) async {
    final id = await createServerBridge(input);
    await reload();
    return id;
  }

  Future<void> updateServer(String id, ServerInput input) async {
    await updateServerBridge(id, input);
    await reload();
  }

  Future<void> deleteServer(String id) async {
    await deleteServerBridge(id);
    await reload();
  }

  Future<void> moveToGroup(String id, String? groupId) async {
    await moveServerToGroup(id: id, groupId: groupId);
    await reload();
  }

  Future<void> updateLastConnected(String id) async {
    await updateLastConnectedBridge(id);
    // Optimistic update of just this server's lastConnected
    final now = DateTime.now().toIso8601String();
    state = state.whenData((servers) => servers.map((s) {
      if (s.id == id) return s.copyWith(lastConnected: now);
      return s;
    }).toList());
  }

  /// Reorders the server list to match [orderedIds]. Servers absent from
  /// [orderedIds] are appended in their existing relative order. The bridge
  /// has no batch reorder endpoint yet, so we reflect the change locally
  /// and reload from the DB on failure.
  Future<void> reorder(List<String> orderedIds) async {
    state = state.whenData((servers) {
      final byId = {for (final s in servers) s.id: s};
      final reordered = <ServerDto>[];
      for (final id in orderedIds) {
        final s = byId.remove(id);
        if (s != null) reordered.add(s);
      }
      reordered.addAll(byId.values);
      return reordered;
    });
  }
}

final serverListProvider = AsyncNotifierProvider<ServerListNotifier, List<ServerDto>>(
  ServerListNotifier.new,
);

/// Provider for a single server (derived from list).
final serverByIdProvider = Provider.family<ServerDto?, String>((ref, id) {
  final list = ref.watch(serverListProvider).valueOrNull;
  return list?.where((s) => s.id == id).firstOrNull;
});
