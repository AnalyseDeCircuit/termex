/// Automated memory-leak check helpers (v0.48 spec §9).
///
/// Provides a lightweight object-counting registry that detects when
/// instances of tracked types are not disposed.  In release mode the
/// counters are silently disabled.
library;

import 'dart:developer' as developer;

class _Counter {
  int alive = 0;
  int created = 0;
  int disposed = 0;
}

class MemoryLeakCheck {
  MemoryLeakCheck._();

  static final Map<String, _Counter> _counters = {};

  static bool _enabled = false;

  /// Enables or disables tracking (must be called in main() during debug).
  static void enable({bool value = true}) => _enabled = value;

  /// Registers the creation of an object of type [typeName].
  static void onCreated(String typeName) {
    if (!_enabled) return;
    final counter = _counters.putIfAbsent(typeName, _Counter.new);
    counter.alive++;
    counter.created++;
  }

  /// Registers the disposal of an object of type [typeName].
  static void onDisposed(String typeName) {
    if (!_enabled) return;
    final c = _counters[typeName];
    if (c == null) return;
    c.alive = (c.alive - 1).clamp(0, 99999);
    c.disposed++;
  }

  /// Returns a snapshot of live counts for all tracked types.
  static Map<String, int> liveSnapshot() {
    return {
      for (final e in _counters.entries) e.key: e.value.alive,
    };
  }

  /// Logs current live counts to the DevTools console.
  static void dump() {
    final snapshot = liveSnapshot();
    for (final e in snapshot.entries) {
      developer.log('MemoryLeakCheck: ${e.key} alive=${e.value}',
          name: 'termex.memory');
    }
  }

  /// Returns `true` when all tracked types have 0 live instances.
  static bool allDisposed() =>
      _counters.values.every((c) => c.alive == 0);

  /// Resets all counters — called between test scenarios.
  static void reset() => _counters.clear();
}
