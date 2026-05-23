/// Tmux controller — tracks tmux session state for a terminal tab.
///
/// Periodically polls `tmux list-panes` via the SSH session and updates
/// [windows].  The terminal view watches this controller to overlay the
/// tmux window/pane bar.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'tmux_pane_model.dart';

export 'tmux_pane_model.dart';

/// Controller that tracks and drives a remote tmux session.
class TmuxController extends ChangeNotifier {
  final String sessionId;

  /// Called to send a raw command string to the SSH session (e.g. tmux commands).
  final Future<void> Function(String command) sendCommand;

  Map<int, TmuxWindow> _windows = {};
  int _activeWindowIndex = 0;
  bool _isAttached = false;
  Timer? _pollTimer;

  TmuxController({
    required this.sessionId,
    required this.sendCommand,
  });

  Map<int, TmuxWindow> get windows => _windows;
  bool get isAttached => _isAttached;
  int get activeWindowIndex => _activeWindowIndex;

  List<TmuxWindow> get windowList {
    final sorted = _windows.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return sorted;
  }

  TmuxWindow? get activeWindow => _windows[_activeWindowIndex];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Start polling for tmux state every [interval].
  void attach({Duration interval = const Duration(seconds: 2)}) {
    if (_isAttached) return;
    _isAttached = true;
    _poll();
    _pollTimer = Timer.periodic(interval, (_) => _poll());
    notifyListeners();
  }

  void detach() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isAttached = false;
    _windows = {};
    notifyListeners();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  // ── Tmux commands ─────────────────────────────────────────────────────────

  Future<void> selectWindow(int index) async {
    await sendCommand('tmux select-window -t :$index');
    _activeWindowIndex = index;
    notifyListeners();
  }

  Future<void> newWindow() async {
    await sendCommand('tmux new-window');
  }

  Future<void> closeWindow(int index) async {
    await sendCommand('tmux kill-window -t :$index');
  }

  Future<void> renameWindow(int index, String name) async {
    await sendCommand("tmux rename-window -t :$index '$name'");
  }

  Future<void> selectPane(String paneId) async {
    await sendCommand('tmux select-pane -t $paneId');
  }

  Future<void> splitPaneHorizontal() async {
    await sendCommand('tmux split-window -h');
  }

  Future<void> splitPaneVertical() async {
    await sendCommand('tmux split-window -v');
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  /// Called when a chunk of tmux output arrives (list-panes response).
  void onPaneListOutput(String output) {
    final parsed = TmuxPaneParser.parse(output);
    if (parsed.isNotEmpty) {
      _windows = parsed;
      // Determine active window by checking which has an active pane.
      for (final w in _windows.values) {
        if (w.panes.any((p) => p.isActive)) {
          _activeWindowIndex = w.index;
          break;
        }
      }
      notifyListeners();
    }
  }

  Future<void> _poll() async {
    try {
      await sendCommand(TmuxPaneParser.listPanesCommand);
    } catch (_) {
      // Ignore poll errors — session may not be in tmux.
    }
  }
}
