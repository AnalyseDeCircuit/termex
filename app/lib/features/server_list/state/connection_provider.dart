import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/tabs/state/tab_controller.dart';
import 'session_provider.dart';

/// Mirrors `useReconnect` from the Vue version.
///
/// Manages the full lifecycle of a tab's connection: connecting → connected →
/// reconnecting (with exponential backoff) → failed / closed.
///
/// Keyed by `tabId` so each tab has independent reconnect state.
enum ReconnectStatus {
  idle,
  connecting,
  connected,
  reconnecting,
  failed,
  closed,
}

class ConnectionState {
  final ReconnectStatus status;
  final String? serverId;
  final String? sessionId;
  final String? lastError;
  final int reconnectAttempt;

  const ConnectionState({
    this.status = ReconnectStatus.idle,
    this.serverId,
    this.sessionId,
    this.lastError,
    this.reconnectAttempt = 0,
  });

  bool get isActive =>
      status == ReconnectStatus.connected ||
      status == ReconnectStatus.connecting ||
      status == ReconnectStatus.reconnecting;

  ConnectionState copyWith({
    ReconnectStatus? status,
    String? serverId,
    String? sessionId,
    String? lastError,
    int? reconnectAttempt,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      serverId: serverId ?? this.serverId,
      sessionId: sessionId ?? this.sessionId,
      lastError: lastError ?? this.lastError,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
    );
  }
}

class ConnectionNotifier
    extends FamilyNotifier<ConnectionState, String> {
  static const int _maxReconnectAttempts = 5;
  static const Duration _baseBackoff = Duration(seconds: 2);

  Timer? _reconnectTimer;

  @override
  ConnectionState build(String tabId) {
    ref.onDispose(() {
      _reconnectTimer?.cancel();
    });
    return const ConnectionState();
  }

  /// Initiate a new connection for [serverId] in this tab.
  Future<void> connect(String serverId, {int cols = 80, int rows = 24}) async {
    _reconnectTimer?.cancel();
    state = ConnectionState(
      status: ReconnectStatus.connecting,
      serverId: serverId,
      reconnectAttempt: 0,
    );

    // Sync tab status indicator.
    ref
        .read(tabListProvider.notifier)
        .updateStatus(arg, TabStatus.connecting);

    try {
      final sessionId = await ref
          .read(sessionProvider(serverId).notifier)
          .open(serverId, cols: cols, rows: rows);

      if (sessionId != null) {
        state = state.copyWith(
          status: ReconnectStatus.connected,
          sessionId: sessionId,
          reconnectAttempt: 0,
        );
        ref
            .read(tabListProvider.notifier)
            .updateStatus(arg, TabStatus.connected);
      } else {
        _onConnectFailure('SSH session could not be opened.');
      }
    } catch (e) {
      _onConnectFailure(e.toString());
    }
  }

  /// Gracefully close the current session.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    final sid = state.sessionId;
    if (sid != null) {
      await ref
          .read(sessionProvider(state.serverId ?? '').notifier)
          .close(sid);
    }
    state = state.copyWith(
      status: ReconnectStatus.closed,
      sessionId: null,
    );
    ref.read(tabListProvider.notifier).updateStatus(arg, TabStatus.disconnected);
  }

  /// Cancel any pending reconnect and mark as failed.
  void cancelReconnect() {
    _reconnectTimer?.cancel();
    state = state.copyWith(status: ReconnectStatus.failed);
    ref.read(tabListProvider.notifier).updateStatus(arg, TabStatus.error);
  }

  void _onConnectFailure(String error) {
    if (state.reconnectAttempt >= _maxReconnectAttempts) {
      state = state.copyWith(
        status: ReconnectStatus.failed,
        lastError: error,
      );
      ref.read(tabListProvider.notifier).updateStatus(arg, TabStatus.error);
      return;
    }

    final attempt = state.reconnectAttempt;
    final backoff = _baseBackoff * math.pow(2, attempt).toDouble();

    state = state.copyWith(
      status: ReconnectStatus.reconnecting,
      lastError: error,
      reconnectAttempt: attempt + 1,
    );
    ref
        .read(tabListProvider.notifier)
        .updateStatus(arg, TabStatus.connecting);

    _reconnectTimer = Timer(backoff, () {
      if (!state.isActive) return;
      if (state.serverId != null) {
        connect(state.serverId!);
      }
    });
  }
}

final connectionProvider =
    NotifierProviderFamily<ConnectionNotifier, ConnectionState, String>(
  ConnectionNotifier.new,
);
