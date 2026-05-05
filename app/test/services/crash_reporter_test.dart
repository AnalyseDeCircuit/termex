import 'package:flutter_test/flutter_test.dart';

import 'package:termex/services/crash_reporter.dart';

class _RecordingReporter implements CrashReporter {
  final errors = <Object>[];
  String? userId;

  @override
  Future<void> report(Object error, StackTrace stack, {Map<String, dynamic>? extras}) async {
    errors.add(error);
  }

  @override
  Future<void> setUserContext({String? userId, Map<String, dynamic>? extra}) async {
    this.userId = userId;
  }
}

void main() {
  setUp(() {
    // Reset to NullCrashReporter between tests.
    CrashReporterRegistry.install(const NullCrashReporter());
  });

  test('default registry is NullCrashReporter', () {
    expect(CrashReporterRegistry.instance, isA<NullCrashReporter>());
  });

  test('NullCrashReporter silently discards reports', () async {
    await CrashReporterRegistry.report(Exception('x'), StackTrace.current);
    // no error thrown, no I/O performed
    expect(CrashReporterRegistry.instance, isA<NullCrashReporter>());
  });

  test('install swaps active reporter', () async {
    final recording = _RecordingReporter();
    CrashReporterRegistry.install(recording);

    await CrashReporterRegistry.report(StateError('boom'), StackTrace.current);

    expect(recording.errors, hasLength(1));
    expect(recording.errors.first, isA<StateError>());
  });

  test('setUserContext is routed through registry', () async {
    final recording = _RecordingReporter();
    CrashReporterRegistry.install(recording);

    await CrashReporterRegistry.instance.setUserContext(userId: 'u-42');

    expect(recording.userId, equals('u-42'));
  });
}
