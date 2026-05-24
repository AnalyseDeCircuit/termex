import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/handoff/model/handoff_view_model.dart';

void main() {
  group('DevicePlatformVM.parse', () {
    test('maps known platforms', () {
      expect(DevicePlatformVM.parse('ios'), DevicePlatformVM.ios);
      expect(DevicePlatformVM.parse('android'), DevicePlatformVM.android);
      expect(DevicePlatformVM.parse('macos'), DevicePlatformVM.macos);
      expect(DevicePlatformVM.parse('linux'), DevicePlatformVM.linux);
      expect(DevicePlatformVM.parse('windows'), DevicePlatformVM.windows);
    });
    test('unknown falls back to unknown', () {
      expect(DevicePlatformVM.parse('plan9'), DevicePlatformVM.unknown);
    });
  });

  group('isMobile', () {
    test('true for iOS / Android', () {
      expect(DevicePlatformVM.ios.isMobile, isTrue);
      expect(DevicePlatformVM.android.isMobile, isTrue);
    });
    test('false for desktop platforms', () {
      for (final p in [
        DevicePlatformVM.macos,
        DevicePlatformVM.linux,
        DevicePlatformVM.windows,
        DevicePlatformVM.unknown,
      ]) {
        expect(p.isMobile, isFalse);
      }
    });
  });

  group('lastSeenHuman', () {
    final now = DateTime.utc(2026, 5, 23, 12, 0, 0);

    DeviceVM at(DateTime ts) => DeviceVM(
          id: 'd',
          name: 'd',
          platform: DevicePlatformVM.ios,
          lastSeenAt: ts,
          isSelf: false,
          isOnline: false,
        );

    test('seconds bucket', () {
      expect(at(now.subtract(const Duration(seconds: 10))).lastSeenHuman(now: now),
          'just now');
    });
    test('minutes bucket', () {
      expect(at(now.subtract(const Duration(minutes: 5))).lastSeenHuman(now: now),
          '5m ago');
    });
    test('hours bucket', () {
      expect(at(now.subtract(const Duration(hours: 3))).lastSeenHuman(now: now),
          '3h ago');
    });
    test('days bucket', () {
      expect(at(now.subtract(const Duration(days: 4))).lastSeenHuman(now: now),
          '4d ago');
    });
    test('months bucket', () {
      expect(at(now.subtract(const Duration(days: 95))).lastSeenHuman(now: now),
          '3mo ago');
    });
  });

  group('DeliveryOutcomeVM', () {
    test('parses known kinds', () {
      expect(DeliveryOutcomeVM.parse('ws'), DeliveryOutcomeVM.ws);
      expect(DeliveryOutcomeVM.parse('fcm'), DeliveryOutcomeVM.fcm);
      expect(DeliveryOutcomeVM.parse('queued'), DeliveryOutcomeVM.queued);
    });
    test('unknown falls back to unknownTarget', () {
      expect(DeliveryOutcomeVM.parse('???'), DeliveryOutcomeVM.unknownTarget);
    });
    test('hintLabel populated for every variant', () {
      for (final o in DeliveryOutcomeVM.values) {
        expect(o.hintLabel.isNotEmpty, isTrue);
      }
    });
  });
}
