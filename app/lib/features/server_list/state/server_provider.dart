import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/server_dto.dart';

// ServerDto and ServerInput come from the FRB-generated bridge.
// Placeholder types are used (defined in models/server_dto.dart) until FRB codegen runs.

// Stub bridge functions — will be replaced by FRB imports in v0.44.
Future<List<ServerDto>> listServers() async => [];
Future<void> createServerBridge(ServerInput input) async {}
Future<void> updateServerBridge(String id, ServerInput input) async {}
Future<void> deleteServerBridge(String id) async {}
Future<void> moveServerToGroup({required String id, required String? groupId}) async {}
Future<void> updateLastConnectedBridge(String id) async {}

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

  Future<void> createServer(ServerInput input) async {
    await createServerBridge(input);
    await reload();
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
}

final serverListProvider = AsyncNotifierProvider<ServerListNotifier, List<ServerDto>>(
  ServerListNotifier.new,
);

/// Provider for a single server (derived from list).
final serverByIdProvider = Provider.family<ServerDto?, String>((ref, id) {
  final list = ref.watch(serverListProvider).valueOrNull;
  return list?.where((s) => s.id == id).firstOrNull;
});
