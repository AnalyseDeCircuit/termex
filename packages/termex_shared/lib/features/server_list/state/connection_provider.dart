import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/api.dart' as bridge;

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
  final bool isLocal;

  // ── Chain progress (v0.68.0 G3) ────────────────────────────────────────────
  /// 1-based index of the hop currently being established. 0 means no chain
  /// (single direct connect).
  final int currentHop;

  /// Total hops in the chain. 0 when no chain in progress.
  final int totalHops;

  /// Human-readable name of the hop being established. Empty when no chain.
  final String hopName;

  /// 0-based attempt counter for the current hop. 0 = first try.
  final int hopAttempt;

  /// Milliseconds until the next retry kicks in, when [status == reconnecting].
  /// 0 means "retrying now" or no retry pending.
  final int nextAttemptInMs;

  const ConnectionState({
    this.status = ReconnectStatus.idle,
    this.serverId,
    this.sessionId,
    this.lastError,
    this.reconnectAttempt = 0,
    this.isLocal = false,
    this.currentHop = 0,
    this.totalHops = 0,
    this.hopName = '',
    this.hopAttempt = 0,
    this.nextAttemptInMs = 0,
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
    bool? isLocal,
    int? currentHop,
    int? totalHops,
    String? hopName,
    int? hopAttempt,
    int? nextAttemptInMs,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      serverId: serverId ?? this.serverId,
      sessionId: sessionId ?? this.sessionId,
      lastError: lastError ?? this.lastError,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      isLocal: isLocal ?? this.isLocal,
      currentHop: currentHop ?? this.currentHop,
      totalHops: totalHops ?? this.totalHops,
      hopName: hopName ?? this.hopName,
      hopAttempt: hopAttempt ?? this.hopAttempt,
      nextAttemptInMs: nextAttemptInMs ?? this.nextAttemptInMs,
    );
  }

  /// Applies one [ChainProgressDto] received from the bridge poll. Maps
  /// each kind onto a ReconnectStatus + the hop progress fields so the
  /// reconnect banner reflects exactly where in the chain we are.
  ConnectionState applyChainEvent(bridge.ChainProgressDto event) {
    switch (event.kind) {
      case 'connecting':
        return copyWith(
          status: event.attempt > 0
              ? ReconnectStatus.reconnecting
              : ReconnectStatus.connecting,
          currentHop: event.hopIndex + 1,
          totalHops: event.hopTotal,
          hopName: event.hopName,
          hopAttempt: event.attempt,
          nextAttemptInMs: 0,
        );
      case 'hopConnected':
        return copyWith(
          currentHop: event.hopIndex + 1,
          totalHops: event.hopTotal,
          hopName: event.hopName,
        );
      case 'hopFailed':
        return copyWith(
          status: event.willRetry
              ? ReconnectStatus.reconnecting
              : ReconnectStatus.failed,
          hopAttempt: event.attempt,
          hopName: event.hopName,
          lastError: event.error,
          nextAttemptInMs: event.nextAttemptInMs.toInt(),
        );
      case 'chainFailed':
        return copyWith(
          status: ReconnectStatus.failed,
          lastError: event.error,
          hopName: event.hopName,
          currentHop: event.hopIndex + 1,
        );
      case 'chainConnected':
        return copyWith(
          status: ReconnectStatus.connected,
          currentHop: totalHops,
          nextAttemptInMs: 0,
        );
      default:
        return this;
    }
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
  ///
  /// When the SSH key is encrypted and the keychain has no stored passphrase,
  /// the bridge surfaces an error matching [_encryptedKeyError]; in that case
  /// [onPassphraseNeeded] is invoked so the caller can show a dialog and
  /// supply the passphrase, which we then persist and retry with.
  Future<void> connect(
    String serverId, {
    int cols = 80,
    int rows = 24,
    Future<String?> Function()? onPassphraseNeeded,
  }) async {
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

    Future<String?> attempt() async {
      return ref
          .read(sessionProvider(serverId).notifier)
          .open(serverId, cols: cols, rows: rows);
    }

    try {
      String? sessionId;
      try {
        sessionId = await attempt();
      } catch (e) {
        if (_isEncryptedKeyError(e.toString()) && onPassphraseNeeded != null) {
          final passphrase = await onPassphraseNeeded();
          if (passphrase == null || passphrase.isEmpty) {
            _onConnectFailure(e.toString());
            return;
          }
          await bridge.sshStorePassphrase(
            serverId: serverId,
            passphrase: passphrase,
          );
          sessionId = await attempt();
        } else {
          rethrow;
        }
      }

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

  static bool _isEncryptedKeyError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('encrypted') ||
        lower.contains('passphrase') ||
        lower.contains('decrypt');
  }

  /// Opens a local shell PTY in this tab. Connects immediately — no server needed.
  Future<void> connectLocal({int cols = 80, int rows = 24}) async {
    _reconnectTimer?.cancel();
    state = const ConnectionState(
      status: ReconnectStatus.connecting,
      isLocal: true,
    );
    ref.read(tabListProvider.notifier).updateStatus(arg, TabStatus.connecting);

    try {
      final sessionId = await bridge.openLocalPty(cols: cols, rows: rows);
      state = ConnectionState(
        status: ReconnectStatus.connected,
        sessionId: sessionId,
        isLocal: true,
      );
      ref.read(tabListProvider.notifier).updateStatus(arg, TabStatus.connected);
    } catch (e) {
      state = ConnectionState(
        status: ReconnectStatus.failed,
        lastError: e.toString(),
        isLocal: true,
      );
      ref.read(tabListProvider.notifier).updateStatus(arg, TabStatus.error);
    }
  }

  /// Gracefully close the current session.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    final sid = state.sessionId;
    if (sid != null) {
      if (state.isLocal) {
        await bridge.closeSshSession(sessionId: sid);
      } else {
        await ref
            .read(sessionProvider(state.serverId ?? '').notifier)
            .close(sid);
      }
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
