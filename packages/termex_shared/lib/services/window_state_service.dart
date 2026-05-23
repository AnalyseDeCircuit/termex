/// Window geometry and open-tab persistence (v0.48 spec §6.2.5).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class WindowState {
  final double width;
  final double height;
  final double x;
  final double y;
  final bool isMaximized;
  /// Server IDs of the last-open tabs (no auto-reconnect on restore).
  final List<String> openTabServerIds;

  const WindowState({
    this.width = 1280,
    this.height = 800,
    this.x = 100,
    this.y = 100,
    this.isMaximized = false,
    this.openTabServerIds = const [],
  });

  WindowState copyWith({
    double? width,
    double? height,
    double? x,
    double? y,
    bool? isMaximized,
    List<String>? openTabServerIds,
  }) =>
      WindowState(
        width: width ?? this.width,
        height: height ?? this.height,
        x: x ?? this.x,
        y: y ?? this.y,
        isMaximized: isMaximized ?? this.isMaximized,
        openTabServerIds: openTabServerIds ?? this.openTabServerIds,
      );
}

// ─── Service ─────────────────────────────────────────────────────────────────

class WindowStateService {
  // In-process cache (substituted by real DB persistence in production).
  WindowState? _cached;

  Future<void> save(WindowState state) async {
    _cached = state;
    // In production: call system::window_state_save via FRB.
  }

  Future<WindowState?> restore() async {
    // In production: call system::window_state_restore via FRB.
    return _cached;
  }

  Future<void> reset() async {
    _cached = null;
    // In production: call system::window_state_reset via FRB.
  }
}

// ─── Riverpod provider ────────────────────────────────────────────────────────

class WindowStateNotifier extends Notifier<WindowState> {
  late final WindowStateService _service;

  @override
  WindowState build() {
    _service = WindowStateService();
    return const WindowState();
  }

  Future<void> load() async {
    final saved = await _service.restore();
    if (saved != null) state = saved;
  }

  Future<void> update(WindowState next) async {
    state = next;
    await _service.save(next);
  }

  Future<void> reset() async {
    await _service.reset();
    state = const WindowState();
  }
}

final windowStateProvider =
    NotifierProvider<WindowStateNotifier, WindowState>(
  WindowStateNotifier.new,
);
