/// Cross-Tab event bus (v0.48 spec §5.1).
///
/// Mirrors Vue's `useBroadcast`.  All events are synchronous and in-process;
/// no IPC or platform channels are required.
library;

import 'dart:async';

// ─── Event hierarchy ─────────────────────────────────────────────────────────

sealed class BroadcastEvent {}

class ServerUpdated extends BroadcastEvent {
  final String serverId;
  ServerUpdated(this.serverId);
}

class SessionClosed extends BroadcastEvent {
  final String sessionId;
  SessionClosed(this.sessionId);
}

class ThemeChanged extends BroadcastEvent {
  final String mode; // 'light' | 'dark' | 'system'
  ThemeChanged(this.mode);
}

class SettingsChanged extends BroadcastEvent {
  final String key;
  SettingsChanged(this.key);
}

class MasterLockTriggered extends BroadcastEvent {
  MasterLockTriggered();
}

class MasterUnlocked extends BroadcastEvent {
  MasterUnlocked();
}

// ─── Bus ─────────────────────────────────────────────────────────────────────

class BroadcastBus {
  BroadcastBus._();

  static final BroadcastBus instance = BroadcastBus._();

  final StreamController<BroadcastEvent> _controller =
      StreamController.broadcast();

  /// Emits an event to all listeners.
  void emit(BroadcastEvent event) => _controller.add(event);

  /// Returns a stream filtered to events of type [T].
  Stream<T> on<T extends BroadcastEvent>() =>
      _controller.stream.where((e) => e is T).cast<T>();

  /// All events (unfiltered).
  Stream<BroadcastEvent> get all => _controller.stream;

  void dispose() => _controller.close();
}
