/// Idle timer for auto-locking the master password (v0.48 spec §5.3).
///
/// Records the last user activity time.  When no activity occurs for
/// [threshold], it emits a [MasterLockTriggered] event to [BroadcastBus].
/// Activity is signalled by calling [IdleTimer.recordActivity].
library;

import 'dart:async';

typedef LockCallback = void Function();

class IdleTimer {
  IdleTimer._();

  static final IdleTimer instance = IdleTimer._();

  Duration _threshold = const Duration(minutes: 30);
  DateTime _lastActivity = DateTime.now();
  Timer? _timer;
  LockCallback? _onLock;

  // ── Configuration ─────────────────────────────────────────────────────────

  /// Configures the idle threshold.  A value of [Duration.zero] disables it.
  void configure({required Duration threshold, LockCallback? onLock}) {
    _threshold = threshold;
    if (onLock != null) _onLock = onLock;
    _restart();
  }

  Duration get threshold => _threshold;

  // ── Activity tracking ─────────────────────────────────────────────────────

  /// Must be called whenever the user interacts with the app (key, pointer, etc.).
  void recordActivity() {
    _lastActivity = DateTime.now();
  }

  DateTime get lastActivity => _lastActivity;

  Duration get idleDuration => DateTime.now().difference(_lastActivity);

  bool get isIdle =>
      _threshold != Duration.zero && idleDuration >= _threshold;

  // ── Internal timer ────────────────────────────────────────────────────────

  void _restart() {
    _timer?.cancel();
    if (_threshold == Duration.zero) return;
    // Poll every 10 s; for test we allow any positive period.
    const pollInterval = Duration(seconds: 10);
    _timer = Timer.periodic(pollInterval, (_) => _check());
  }

  void _check() {
    if (isIdle) {
      _timer?.cancel();
      _timer = null;
      _onLock?.call();
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void start() => _restart();

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    recordActivity();
    _restart();
  }

  /// Triggers the lock callback immediately (used in tests and for manual lock).
  void forceLock() {
    stop();
    _onLock?.call();
  }
}
