/// Crash reporter interface — v0.49 spec §13.8.
///
/// Per CLAUDE.md telemetry policy, v0.49.0 ships with [NullCrashReporter]
/// wired up.  Any production reporter (Sentry, Firebase Crashlytics, etc.)
/// must be activated behind a user opt-in that defaults to off.
library;

abstract class CrashReporter {
  Future<void> report(
    Object error,
    StackTrace stack, {
    Map<String, dynamic>? extras,
  });

  Future<void> setUserContext({
    String? userId,
    Map<String, dynamic>? extra,
  });
}

/// Default implementation shipped in v0.49.0.  No telemetry leaves the device.
class NullCrashReporter implements CrashReporter {
  const NullCrashReporter();

  @override
  Future<void> report(Object error, StackTrace stack, {Map<String, dynamic>? extras}) async {}

  @override
  Future<void> setUserContext({String? userId, Map<String, dynamic>? extra}) async {}
}

/// Holds the active reporter.  Call [CrashReporterRegistry.install] at app
/// boot with [NullCrashReporter] (the only v0.49 option).  v0.50+ may swap
/// in an opt-in provider here.
class CrashReporterRegistry {
  CrashReporterRegistry._();

  static CrashReporter _instance = const NullCrashReporter();

  static CrashReporter get instance => _instance;

  static void install(CrashReporter reporter) {
    _instance = reporter;
  }

  /// Captured reports for assertions in tests; no-op for the null reporter.
  static Future<void> report(
    Object error,
    StackTrace stack, {
    Map<String, dynamic>? extras,
  }) =>
      _instance.report(error, stack, extras: extras);
}
