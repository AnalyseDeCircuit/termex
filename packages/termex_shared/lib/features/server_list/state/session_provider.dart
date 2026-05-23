import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

enum ConnectionStatus { idle, connecting, connected, error }

class SessionState {
  final String? sessionId;
  final ConnectionStatus status;
  final String? errorMessage;

  const SessionState({
    this.sessionId,
    required this.status,
    this.errorMessage,
  });

  bool get isConnected => status == ConnectionStatus.connected;

  SessionState copyWith({String? sessionId, ConnectionStatus? status, String? errorMessage}) {
    return SessionState(
      sessionId: sessionId ?? this.sessionId,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class SessionNotifier extends FamilyNotifier<SessionState, String> {
  @override
  SessionState build(String serverId) {
    return const SessionState(status: ConnectionStatus.idle);
  }

  Future<String?> open(String serverId, {int cols = 80, int rows = 24}) async {
    state = const SessionState(status: ConnectionStatus.connecting);
    try {
      final sessionId = await bridge.openSshSession(
        serverId: serverId,
        cols: cols,
        rows: rows,
      );
      state = SessionState(
        sessionId: sessionId,
        status: ConnectionStatus.connected,
      );
      return sessionId;
    } catch (e) {
      state = SessionState(
        status: ConnectionStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<void> close(String sessionId) async {
    try {
      await bridge.closeSshSession(sessionId: sessionId);
    } catch (_) {
      // swallow — we still want to reset UI state
    }
    state = const SessionState(status: ConnectionStatus.idle);
  }
}

final sessionProvider = NotifierProviderFamily<SessionNotifier, SessionState, String>(
  SessionNotifier.new,
);
