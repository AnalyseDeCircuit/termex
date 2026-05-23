/// Tmux session detection providers (P1.5).
///
/// Two pieces of state:
///   1. [tmuxModeProvider] — user preference: auto / on / off. Persisted via
///      SharedPreferences. "auto" defers to heuristic detection.
///   2. [isTmuxAttachedProvider] — per-session attach state derived from a
///      [TmuxController] keyed by sessionId. The controller is created on
///      first attach and torn down with the session.
///
/// Heuristic detection: we tag a session as "tmux-attached" once we see a
/// recognizable tmux DCS prefix (`\x1bP=...`) or status-line escape in the
/// PTY output stream. The terminal_pane poll loop notifies this provider via
/// [TmuxAttachNotifier.markDetected].
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TmuxMode {
  auto,
  on,
  off;

  String get label => switch (this) {
        TmuxMode.auto => '自动检测',
        TmuxMode.on => '始终启用',
        TmuxMode.off => '关闭',
      };
}

class TmuxModeNotifier extends AsyncNotifier<TmuxMode> {
  static const _key = 'termex.tmux_mode';

  @override
  Future<TmuxMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return TmuxMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => TmuxMode.auto,
    );
  }

  Future<void> set(TmuxMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
    state = AsyncData(mode);
  }
}

final tmuxModeProvider =
    AsyncNotifierProvider<TmuxModeNotifier, TmuxMode>(TmuxModeNotifier.new);

/// Per-session attach detection state. The set holds session IDs that have
/// been heuristically identified as running tmux.
class TmuxAttachNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void markDetected(String sessionId) {
    if (state.contains(sessionId)) return;
    state = {...state, sessionId};
  }

  void clear(String sessionId) {
    if (!state.contains(sessionId)) return;
    final next = Set<String>.from(state)..remove(sessionId);
    state = next;
  }
}

final tmuxAttachProvider =
    NotifierProvider<TmuxAttachNotifier, Set<String>>(TmuxAttachNotifier.new);

/// True when the given session is currently considered tmux-attached.
/// Respects [tmuxModeProvider]:
///   - off  → always false
///   - on   → always true (user override)
///   - auto → true iff [tmuxAttachProvider] saw a tmux signal for this session
final isTmuxAttachedProvider = Provider.family<bool, String>((ref, sessionId) {
  final mode = ref.watch(tmuxModeProvider).valueOrNull ?? TmuxMode.auto;
  switch (mode) {
    case TmuxMode.off:
      return false;
    case TmuxMode.on:
      return true;
    case TmuxMode.auto:
      return ref.watch(tmuxAttachProvider).contains(sessionId);
  }
});

/// Tmux DCS / status line signal patterns. When any matches a chunk of PTY
/// output, the originating session is flagged as tmux-attached.
final RegExp tmuxSignalPattern = RegExp(
  // DCS device passthrough used by tmux for ESC sequences from inside panes.
  r'\x1bP=\d+s|'
  // Tmux 1006 mouse mode setup is distinctive when run under multiplexing.
  r'\x1b\]2;tmux\x07|'
  // Status line refresh sets a window title prefix the multiplexer uses.
  r'\x1b\]0;.*?tmux.*?\x07',
);
