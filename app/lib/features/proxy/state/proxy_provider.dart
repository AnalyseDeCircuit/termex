import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;
import 'package:termex_bridge/src/models.dart' as bridge_models;
import 'package:uuid/uuid.dart';

// ─── DTOs ────────────────────────────────────────────────────────────────────

enum ProxyType { socks5, http, tor }

extension ProxyTypeLabel on ProxyType {
  String get label {
    switch (this) {
      case ProxyType.socks5:
        return 'SOCKS5';
      case ProxyType.http:
        return 'HTTP';
      case ProxyType.tor:
        return 'Tor';
    }
  }
}

class ProxyConfig {
  final String id;
  final ProxyType proxyType;
  final String host;
  final int port;
  final String? username;
  final bool isDefault;

  const ProxyConfig({
    required this.id,
    required this.proxyType,
    required this.host,
    required this.port,
    this.username,
    required this.isDefault,
  });

  String get address => '$host:$port';

  ProxyConfig copyWith({bool? isDefault}) => ProxyConfig(
        id: id,
        proxyType: proxyType,
        host: host,
        port: port,
        username: username,
        isDefault: isDefault ?? this.isDefault,
      );
}

// ─── State ────────────────────────────────────────────────────────────────────

class ProxyState {
  final List<ProxyConfig> proxies;
  final bool isLoading;
  final String? error;
  final String? testingId;

  const ProxyState({
    this.proxies = const [],
    this.isLoading = false,
    this.error,
    this.testingId,
  });

  ProxyConfig? get defaultProxy => proxies.where((p) => p.isDefault).firstOrNull;

  ProxyState copyWith({
    List<ProxyConfig>? proxies,
    bool? isLoading,
    String? error,
    String? testingId,
    bool clearError = false,
    bool clearTesting = false,
  }) =>
      ProxyState(
        proxies: proxies ?? this.proxies,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        testingId: clearTesting ? null : (testingId ?? this.testingId),
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class ProxyNotifier extends Notifier<ProxyState> {
  @override
  ProxyState build() => const ProxyState();

  ProxyConfig _fromBridge(bridge_models.ProxyConfig b) => ProxyConfig(
        id: b.id,
        proxyType: switch (b.proxyType) {
          bridge_models.ProxyType.socks5 => ProxyType.socks5,
          bridge_models.ProxyType.http => ProxyType.http,
          bridge_models.ProxyType.tor => ProxyType.tor,
        },
        host: b.host,
        port: b.port,
        username: b.username,
        isDefault: b.isDefault,
      );

  String _typeStr(ProxyType t) => switch (t) {
        ProxyType.socks5 => 'socks5',
        ProxyType.http => 'http',
        ProxyType.tor => 'tor',
      };

  Future<void> loadProxies() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final remote = await bridge.proxyList();
      state = state.copyWith(
        proxies: remote.map(_fromBridge).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createProxy({
    required ProxyType proxyType,
    required String host,
    required int port,
    String? username,
  }) async {
    state = state.copyWith(clearError: true);
    final optimistic = ProxyConfig(
      id: const Uuid().v4(),
      proxyType: proxyType,
      host: host,
      port: port,
      username: username,
      isDefault: state.proxies.isEmpty,
    );
    state = state.copyWith(proxies: [...state.proxies, optimistic]);
    try {
      final created = await bridge.proxyCreate(
        proxyType: switch (proxyType) {
          ProxyType.socks5 => bridge_models.ProxyType.socks5,
          ProxyType.http => bridge_models.ProxyType.http,
          ProxyType.tor => bridge_models.ProxyType.tor,
        },
        host: host,
        port: port,
        username: username,
      );
      final reconciled = state.proxies
          .map((p) => p.id == optimistic.id ? _fromBridge(created) : p)
          .toList();
      state = state.copyWith(proxies: reconciled);
    } catch (_) {
      // Bridge unavailable — keep optimistic state.
    }
  }

  Future<void> deleteProxy(String id) async {
    try {
      await bridge.proxyDelete(id: id);
    } catch (_) {}
    state = state.copyWith(
      proxies: state.proxies.where((p) => p.id != id).toList(),
    );
  }

  Future<void> setDefault(String id) async {
    try {
      await bridge.proxySetDefault(id: id);
    } catch (_) {}
    final updated = state.proxies.map((p) => p.copyWith(isDefault: p.id == id)).toList();
    state = state.copyWith(proxies: updated);
  }

  Future<void> testConnection(String id) async {
    state = state.copyWith(testingId: id, clearError: true);
    try {
      final ok = await bridge.proxyTestConnection(id: id);
      state = state.copyWith(
        clearTesting: true,
        error: ok ? null : 'Connection test failed',
        clearError: ok,
      );
    } catch (e) {
      state = state.copyWith(clearTesting: true, error: e.toString());
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final proxyProvider =
    NotifierProvider<ProxyNotifier, ProxyState>(ProxyNotifier.new);
