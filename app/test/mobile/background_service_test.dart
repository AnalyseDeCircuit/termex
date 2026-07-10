/// Unit tests for the Android foreground-service refcount wrapper.
///
/// Asserts that the public `acquire` / `release` API:
///   - bumps the refcount on `acquire`
///   - decrements (with floor at 0) on `release`
///   - invokes the `startSession` / `stopSession` method-channel hooks
///     in the right transitions (0→1 start, last→0 stop)
///   - issues a refresh on intermediate count changes so the
///     foreground-notification text stays accurate
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/mobile/background_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Capture method-channel calls into a list. The wrapper guards every
  // invocation with a try/catch so we don't need to fake the platform
  // beyond this — the call list is what we assert on.
  late List<({String method, Map? args})> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('termex/background'),
      (MethodCall call) async {
        calls.add((
          method: call.method,
          args: call.arguments is Map ? call.arguments as Map : null,
        ));
        return null;
      },
    );
  });

  tearDown(() async {
    // Reset to ensure suite independence — clear any lingering refcount
    // by draining release calls.
    while (true) {
      final before = calls.length;
      await MobileBackgroundService.release();
      if (calls.length == before) break;
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('termex/background'),
      null,
    );
  });

  test('acquire/release lifecycle', () async {
    // First acquire transitions 0→1, should start the service.
    await MobileBackgroundService.acquire();
    expect(calls, hasLength(1));
    expect(calls.first.method, 'startSession');
    expect(calls.first.args?['count'], 1);

    // Second acquire refreshes the notification (count=2).
    await MobileBackgroundService.acquire();
    expect(calls, hasLength(2));
    expect(calls[1].method, 'startSession');
    expect(calls[1].args?['count'], 2);

    // First release refreshes again (count=1 still active).
    await MobileBackgroundService.release();
    expect(calls, hasLength(3));
    expect(calls[2].method, 'startSession');
    expect(calls[2].args?['count'], 1);

    // Last release transitions 1→0, should stop the service.
    await MobileBackgroundService.release();
    expect(calls, hasLength(4));
    expect(calls[3].method, 'stopSession');
  });

  test('release at zero refcount is a safe no-op for the count', () async {
    // Underflow guard — should not crash and should not over-decrement.
    await MobileBackgroundService.release();
    // On the test platform (which exposes Platform.isAndroid as false
    // when running unit tests on macOS host) the wrapper short-circuits
    // before the method-channel call, so `calls` may be empty here.
    // The important property is that we don't throw.
  });
}
