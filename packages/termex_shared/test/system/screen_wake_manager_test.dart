import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/system/screen_wake_manager.dart';

void main() {
  group('ScreenWakeManager.shouldEnable', () {
    test('off when app is backgrounded', () {
      const inputs = ScreenWakeInputs(
        appInForeground: false,
        hasRunningTask: true,
        userPreference: true,
      );
      expect(ScreenWakeManager.shouldEnable(inputs), isFalse);
    });

    test('off when no running task', () {
      const inputs = ScreenWakeInputs(
        appInForeground: true,
        hasRunningTask: false,
        userPreference: true,
      );
      expect(ScreenWakeManager.shouldEnable(inputs), isFalse);
    });

    test('on when foreground + running + userPreference', () {
      const inputs = ScreenWakeInputs(
        appInForeground: true,
        hasRunningTask: true,
        userPreference: true,
      );
      expect(ScreenWakeManager.shouldEnable(inputs), isTrue);
    });

    test('charging override kicks in when userPreference off', () {
      const inputs = ScreenWakeInputs(
        appInForeground: true,
        hasRunningTask: true,
        userPreference: false,
        charging: true,
        keepOnWhileCharging: true,
      );
      expect(ScreenWakeManager.shouldEnable(inputs), isTrue);
    });

    test('charging override respects keepOnWhileCharging=false', () {
      const inputs = ScreenWakeInputs(
        appInForeground: true,
        hasRunningTask: true,
        userPreference: false,
        charging: true,
        keepOnWhileCharging: false,
      );
      expect(ScreenWakeManager.shouldEnable(inputs), isFalse);
    });

    test('off when user opts out and not charging', () {
      const inputs = ScreenWakeInputs(
        appInForeground: true,
        hasRunningTask: true,
        userPreference: false,
        charging: false,
      );
      expect(ScreenWakeManager.shouldEnable(inputs), isFalse);
    });
  });

  group('ScreenWakeManager.reason', () {
    test('explains foreground gate', () {
      expect(
        ScreenWakeManager.reason(const ScreenWakeInputs(
          appInForeground: false,
          hasRunningTask: true,
          userPreference: true,
        )),
        contains('backgrounded'),
      );
    });

    test('explains no-task gate', () {
      expect(
        ScreenWakeManager.reason(const ScreenWakeInputs(
          appInForeground: true,
          hasRunningTask: false,
        )),
        contains('no running task'),
      );
    });

    test('cites user preference when enabled', () {
      expect(
        ScreenWakeManager.reason(const ScreenWakeInputs(
          appInForeground: true,
          hasRunningTask: true,
          userPreference: true,
        )),
        contains('user preference'),
      );
    });

    test('cites charging extra when that is the reason', () {
      expect(
        ScreenWakeManager.reason(const ScreenWakeInputs(
          appInForeground: true,
          hasRunningTask: true,
          userPreference: false,
          charging: true,
          keepOnWhileCharging: true,
        )),
        contains('charging extra'),
      );
    });

    test('cites opt-out when nothing else applies', () {
      expect(
        ScreenWakeManager.reason(const ScreenWakeInputs(
          appInForeground: true,
          hasRunningTask: true,
          userPreference: false,
        )),
        contains('opted out'),
      );
    });
  });
}
