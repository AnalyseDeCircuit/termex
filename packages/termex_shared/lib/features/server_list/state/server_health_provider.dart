import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'server_provider.dart';

enum ServerHealthStatus { unknown, healthy, degraded, unreachable }

class _ServerHealthNotifier
    extends StateNotifier<Map<String, ServerHealthStatus>> {
  final Ref _ref;
  Timer? _timer;
  bool _polling = false;

  _ServerHealthNotifier(this._ref) : super(const {}) {
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final servers = _ref.read(serverListProvider).valueOrNull ?? [];
      final results = Map<String, ServerHealthStatus>.from(state);
      for (final s in servers) {
        results[s.id] = await _check(s.host, s.port);
        // 100 ms between checks to avoid thundering-herd on large lists.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      state = results;
    } finally {
      _polling = false;
    }
  }

  static bool _isPrivateOrLocalHost(String host) {
    if (host == 'localhost' || host == '::1') return true;
    // IPv4 loopback
    if (host.startsWith('127.')) return true;
    // RFC 1918 private ranges
    if (host.startsWith('10.')) return true;
    if (host.startsWith('192.168.')) return true;
    final parts = host.split('.');
    if (parts.length == 4) {
      final second = int.tryParse(parts[1]);
      if (parts[0] == '172' && second != null && second >= 16 && second <= 31) {
        return true;
      }
    }
    return false;
  }

  static Future<ServerHealthStatus> _check(String host, int port) async {
    if (_isPrivateOrLocalHost(host)) return ServerHealthStatus.unknown;
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return sw.elapsedMilliseconds > 500
          ? ServerHealthStatus.degraded
          : ServerHealthStatus.healthy;
    } catch (_) {
      return ServerHealthStatus.unreachable;
    }
  }
}

final serverHealthProvider =
    StateNotifierProvider<_ServerHealthNotifier, Map<String, ServerHealthStatus>>(
  (ref) => _ServerHealthNotifier(ref),
);
