/// Performance profiling integration (v0.48 spec §8.2).
///
/// Thin wrapper around Flutter DevTools timeline events.  In release mode all
/// calls compile to no-ops so there is zero overhead in production.
library;

import 'dart:developer' as developer;

class ProfileHelper {
  ProfileHelper._();

  static void markStart(String name) {
    developer.Timeline.startSync(name);
  }

  static void markEnd(String name) {
    developer.Timeline.finishSync();
  }

  /// Synchronously measures [name] around [body] and records a timeline slice.
  static T measure<T>(String name, T Function() body) {
    markStart(name);
    try {
      return body();
    } finally {
      markEnd(name);
    }
  }

  /// Asynchronously measures [name] around [body].
  static Future<T> measureAsync<T>(
      String name, Future<T> Function() body) async {
    markStart(name);
    try {
      return await body();
    } finally {
      markEnd(name);
    }
  }

  /// Emits a named instant marker in the DevTools timeline.
  static void instant(String name) {
    developer.Timeline.instantSync(name);
  }
}
