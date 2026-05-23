import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

class QuickConnectEntry {
  final String id;
  final String host;
  final int port;
  final String username;
  final String usedAt;

  const QuickConnectEntry({
    required this.id, required this.host, required this.port,
    required this.username, required this.usedAt,
  });
}

/// Parse a quick-connect string in formats:
/// - user@host
/// - user@host:port
/// - host
/// - host:port
class QuickConnectParser {
  static ({String host, int port, String username}) parse(String input) {
    String username = '';
    String hostPart = input.trim();

    if (hostPart.contains('@')) {
      final parts = hostPart.split('@');
      username = parts[0];
      hostPart = parts.sublist(1).join('@');
    }

    int port = 22;
    if (hostPart.contains(':')) {
      final lastColon = hostPart.lastIndexOf(':');
      final portStr = hostPart.substring(lastColon + 1);
      final parsed = int.tryParse(portStr);
      if (parsed != null && parsed > 0 && parsed <= 65535) {
        port = parsed;
        hostPart = hostPart.substring(0, lastColon);
      }
    }

    return (host: hostPart, port: port, username: username);
  }
}

Future<List<QuickConnectEntry>> _fetch() async {
  try {
    final remote = await bridge.listQuickConnectHistory();
    return remote
        .map((e) => QuickConnectEntry(
              id: e.id,
              host: e.host,
              port: e.port,
              username: e.username,
              usedAt: e.usedAt,
            ))
        .toList();
  } catch (_) {
    return const <QuickConnectEntry>[];
  }
}

class QuickConnectHistoryNotifier extends AsyncNotifier<List<QuickConnectEntry>> {
  @override
  Future<List<QuickConnectEntry>> build() => _fetch();

  Future<void> add(String host, int port, String username) async {
    await bridge.addQuickConnectHistory(
      host: host,
      port: port,
      username: username,
    );
    await reload();
  }

  Future<void> clear() async {
    await bridge.clearQuickConnectHistory();
    await reload();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

final quickConnectHistoryProvider = AsyncNotifierProvider<QuickConnectHistoryNotifier, List<QuickConnectEntry>>(
  QuickConnectHistoryNotifier.new,
);
