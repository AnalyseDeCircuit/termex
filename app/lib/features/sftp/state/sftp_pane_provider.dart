/// Riverpod provider for SFTP dual-pane UI state.
///
/// Tracks the current path and selected files in both the local and remote
/// panes.  Layout state (split ratio, which side is focused) also lives here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for one pane (local or remote).
class PaneState {
  final String currentPath;
  final Set<String> selectedNames;
  final bool isLoading;
  final String? errorMessage;

  const PaneState({
    required this.currentPath,
    this.selectedNames = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  PaneState copyWith({
    String? currentPath,
    Set<String>? selectedNames,
    bool? isLoading,
    String? errorMessage,
  }) =>
      PaneState(
        currentPath: currentPath ?? this.currentPath,
        selectedNames: selectedNames ?? this.selectedNames,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

enum ActivePane { local, remote }

class SftpPaneState {
  final PaneState local;
  final PaneState remote;
  final ActivePane activePane;
  final double splitRatio;

  const SftpPaneState({
    required this.local,
    required this.remote,
    this.activePane = ActivePane.local,
    this.splitRatio = 0.5,
  });

  SftpPaneState copyWith({
    PaneState? local,
    PaneState? remote,
    ActivePane? activePane,
    double? splitRatio,
  }) =>
      SftpPaneState(
        local: local ?? this.local,
        remote: remote ?? this.remote,
        activePane: activePane ?? this.activePane,
        splitRatio: splitRatio ?? this.splitRatio,
      );
}

class SftpPaneNotifier extends FamilyNotifier<SftpPaneState, String> {
  @override
  SftpPaneState build(String sessionId) => SftpPaneState(
        local: PaneState(currentPath: _homeDir()),
        remote: const PaneState(currentPath: '~'),
      );

  // ── Focus ─────────────────────────────────────────────────────────────────

  void focusLocal() =>
      state = state.copyWith(activePane: ActivePane.local);

  void focusRemote() =>
      state = state.copyWith(activePane: ActivePane.remote);

  void updateSplitRatio(double ratio) =>
      state = state.copyWith(splitRatio: ratio.clamp(0.2, 0.8));

  // ── Navigation ────────────────────────────────────────────────────────────

  void navigateLocal(String path) {
    state = state.copyWith(
      local: state.local.copyWith(
          currentPath: path, selectedNames: {}, errorMessage: null),
    );
  }

  void navigateRemote(String path) {
    state = state.copyWith(
      remote: state.remote.copyWith(
          currentPath: path, selectedNames: {}, errorMessage: null),
    );
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  void toggleLocalSelection(String name) {
    final sel = Set<String>.from(state.local.selectedNames);
    if (!sel.remove(name)) sel.add(name);
    state = state.copyWith(local: state.local.copyWith(selectedNames: sel));
  }

  void toggleRemoteSelection(String name) {
    final sel = Set<String>.from(state.remote.selectedNames);
    if (!sel.remove(name)) sel.add(name);
    state = state.copyWith(remote: state.remote.copyWith(selectedNames: sel));
  }

  void clearLocalSelection() =>
      state = state.copyWith(local: state.local.copyWith(selectedNames: {}));

  void clearRemoteSelection() =>
      state =
          state.copyWith(remote: state.remote.copyWith(selectedNames: {}));

  // ── Loading state helpers ─────────────────────────────────────────────────

  void setLocalLoading(bool loading) =>
      state = state.copyWith(local: state.local.copyWith(isLoading: loading));

  void setRemoteLoading(bool loading) =>
      state =
          state.copyWith(remote: state.remote.copyWith(isLoading: loading));

  void setRemoteError(String? error) => state =
      state.copyWith(remote: state.remote.copyWith(errorMessage: error));

  // ── Internal ─────────────────────────────────────────────────────────────

  static String _homeDir() {
    // Derive home path per platform; FRB localHomeDir is async so start with a
    // reasonable default and let LocalPane call navigateLocal after boot.
    return '/';
  }
}

final sftpPaneProvider = NotifierProvider.family<SftpPaneNotifier,
    SftpPaneState, String>(SftpPaneNotifier.new);
