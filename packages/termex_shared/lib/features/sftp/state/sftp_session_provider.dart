/// Riverpod provider for SFTP channel state per SSH session.
///
/// One [SftpSessionNotifier] is created per sessionId (Family key).
/// It tracks whether the SFTP channel is open and the current remote
/// working directory.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

enum SftpChannelStatus { closed, opening, open, error }

class SftpSessionState {
  final SftpChannelStatus status;
  final String? errorMessage;
  final String remoteCwd;

  const SftpSessionState({
    this.status = SftpChannelStatus.closed,
    this.errorMessage,
    this.remoteCwd = '~',
  });

  bool get isOpen => status == SftpChannelStatus.open;

  SftpSessionState copyWith({
    SftpChannelStatus? status,
    String? errorMessage,
    String? remoteCwd,
  }) =>
      SftpSessionState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        remoteCwd: remoteCwd ?? this.remoteCwd,
      );
}

class SftpSessionNotifier
    extends FamilyNotifier<SftpSessionState, String> {
  @override
  SftpSessionState build(String sessionId) {
    // Auto-close SFTP channel when this notifier is disposed.
    ref.onDispose(() => _closeIfOpen());
    return const SftpSessionState();
  }

  Future<void> open() async {
    if (state.isOpen) return;
    state = state.copyWith(status: SftpChannelStatus.opening);
    try {
      await bridge.openSftpChannel(sessionId: arg);
      final home = await bridge.sftpCanonicalize(sessionId: arg, path: '.')
          .catchError((_) => '~');
      state = state.copyWith(status: SftpChannelStatus.open, remoteCwd: home);
    } catch (e) {
      state = state.copyWith(
        status: SftpChannelStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> close() async {
    await _closeIfOpen();
    state = const SftpSessionState();
  }

  Future<void> changeDirectory(String path) async {
    if (!state.isOpen) return;
    try {
      final resolved =
          await bridge.sftpCanonicalize(sessionId: arg, path: path);
      state = state.copyWith(remoteCwd: resolved);
    } catch (_) {
      // fall back to requested path if canonicalize fails
      state = state.copyWith(remoteCwd: path);
    }
  }

  Future<void> _closeIfOpen() async {
    if (!state.isOpen) return;
    try {
      await bridge.closeSftpChannel(sessionId: arg);
    } catch (_) {}
  }
}

final sftpSessionProvider = NotifierProvider.family<SftpSessionNotifier,
    SftpSessionState, String>(SftpSessionNotifier.new);
