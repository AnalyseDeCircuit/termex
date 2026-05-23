import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;
import 'package:termex_bridge/src/models.dart' as bridge_models;

// ─── DTOs ────────────────────────────────────────────────────────────────────

enum ForwardType { local, remote, dynamic }

extension ForwardTypeLabel on ForwardType {
  String get label {
    switch (this) {
      case ForwardType.local:
        return 'Local';
      case ForwardType.remote:
        return 'Remote';
      case ForwardType.dynamic:
        return 'Dynamic (SOCKS5)';
    }
  }
}

class ForwardRule {
  final String id;
  final String sessionId;
  final ForwardType forwardType;
  final int localPort;
  final String remoteHost;
  final int remotePort;
  final bool isActive;

  const ForwardRule({
    required this.id,
    required this.sessionId,
    required this.forwardType,
    required this.localPort,
    required this.remoteHost,
    required this.remotePort,
    required this.isActive,
  });

  String get summary {
    switch (forwardType) {
      case ForwardType.local:
        return 'localhost:$localPort → $remoteHost:$remotePort';
      case ForwardType.remote:
        return '$remoteHost:$remotePort → localhost:$localPort';
      case ForwardType.dynamic:
        return 'SOCKS5 localhost:$localPort';
    }
  }
}

// ─── State ────────────────────────────────────────────────────────────────────

class PortForwardState {
  final List<ForwardRule> rules;
  final bool isLoading;
  final String? error;

  const PortForwardState({
    this.rules = const [],
    this.isLoading = false,
    this.error,
  });

  PortForwardState copyWith({
    List<ForwardRule>? rules,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      PortForwardState(
        rules: rules ?? this.rules,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class PortForwardNotifier extends Notifier<PortForwardState> {
  @override
  PortForwardState build() => const PortForwardState();

  ForwardRule _fromBridge(bridge_models.ForwardRule b) => ForwardRule(
        id: b.id,
        sessionId: b.sessionId,
        forwardType: switch (b.forwardType) {
          bridge_models.ForwardType.local => ForwardType.local,
          bridge_models.ForwardType.remote => ForwardType.remote,
          bridge_models.ForwardType.dynamic_ => ForwardType.dynamic,
        },
        localPort: b.localPort,
        remoteHost: b.remoteHost,
        remotePort: b.remotePort,
        isActive: b.isActive,
      );

  String _dirStr(ForwardType t) => switch (t) {
        ForwardType.local => 'local',
        ForwardType.remote => 'remote',
        ForwardType.dynamic => 'dynamic',
      };

  Future<void> loadRules(String sessionId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final remote = await bridge.portForwardList(sessionId: sessionId);
      state = state.copyWith(
        rules: remote.map(_fromBridge).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addRule({
    required String sessionId,
    required ForwardType forwardType,
    required int localPort,
    required String remoteHost,
    required int remotePort,
  }) async {
    state = state.copyWith(clearError: true);
    String ruleId;
    try {
      ruleId = await bridge.portForwardStart(
        sessionId: sessionId,
        forwardType: switch (forwardType) {
          ForwardType.local => bridge_models.ForwardType.local,
          ForwardType.remote => bridge_models.ForwardType.remote,
          ForwardType.dynamic => bridge_models.ForwardType.dynamic_,
        },
        localPort: localPort,
        remoteHost: remoteHost,
        remotePort: remotePort,
      );
    } catch (_) {
      ruleId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    }
    state = state.copyWith(rules: [
      ...state.rules,
      ForwardRule(
        id: ruleId,
        sessionId: sessionId,
        forwardType: forwardType,
        localPort: localPort,
        remoteHost: remoteHost,
        remotePort: remotePort,
        isActive: true,
      ),
    ]);
  }

  Future<void> removeRule(String ruleId) async {
    try {
      await bridge.portForwardStop(ruleId: ruleId);
    } catch (_) {}
    state = state.copyWith(
      rules: state.rules.where((r) => r.id != ruleId).toList(),
    );
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final portForwardProvider =
    NotifierProvider<PortForwardNotifier, PortForwardState>(PortForwardNotifier.new);
