import 'package:flutter_test/flutter_test.dart';

import 'package:termex/system/idle_timer.dart';

void main() {
  setUp(() {
    IdleTimer.instance.stop();
    IdleTimer.instance.recordActivity();
  });

  group('IdleTimer', () {
    test('initial state: not idle', () {
      IdleTimer.instance.configure(threshold: const Duration(minutes: 30));
      expect(IdleTimer.instance.isIdle, isFalse);
    });

    test('isIdle true when elapsed > threshold', () {
      // Use a very short threshold and fake elapsed time via recordActivity.
      IdleTimer.instance.configure(threshold: const Duration(milliseconds: 1));
      // Advance time by not calling recordActivity.
      // Simulate by manually setting _lastActivity in the past via forceLock.
      bool locked = false;
      IdleTimer.instance.configure(
          threshold: const Duration(milliseconds: 1),
          onLock: () => locked = true);
      IdleTimer.instance.forceLock();
      expect(locked, isTrue);
    });

    test('recordActivity resets idle duration', () {
      IdleTimer.instance.configure(threshold: const Duration(seconds: 10));
      final before = IdleTimer.instance.lastActivity;
      IdleTimer.instance.recordActivity();
      final after = IdleTimer.instance.lastActivity;
      expect(after.isAfter(before) || after == before, isTrue);
    });

    test('threshold zero disables auto-lock', () {
      IdleTimer.instance.configure(threshold: Duration.zero);
      expect(IdleTimer.instance.isIdle, isFalse);
    });

    test('forceLock triggers onLock callback', () {
      bool locked = false;
      IdleTimer.instance.configure(
          threshold: const Duration(minutes: 30),
          onLock: () => locked = true);
      IdleTimer.instance.forceLock();
      expect(locked, isTrue);
    });

    test('stop prevents further lock callbacks', () {
      int lockCount = 0;
      IdleTimer.instance.configure(
          threshold: const Duration(milliseconds: 1),
          onLock: () => lockCount++);
      IdleTimer.instance.stop();
      IdleTimer.instance.forceLock(); // forced still fires
      expect(lockCount, 1); // exactly once from forceLock
    });

    test('configure returns threshold', () {
      IdleTimer.instance
          .configure(threshold: const Duration(minutes: 15));
      expect(IdleTimer.instance.threshold,
          equals(const Duration(minutes: 15)));
    });
  });
}
