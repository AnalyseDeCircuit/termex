import 'package:flutter_test/flutter_test.dart';
import 'package:termex/system/sentinel_flag.dart';

void main() {
  group('kSentinelEnabled default', () {
    test('is false in dev/default-release builds', () {
      // Default invocation of `flutter test` never passes --dart-define=SENTINEL,
      // so kSentinelEnabled must resolve to the default false. This test is
      // the canary that keeps the trap payloads tree-shaken out.
      expect(kSentinelEnabled, isFalse);
    });

    test('kBuildSignature encodes canonical TERM marker', () {
      // 0x5445_524D == bytes T E R M in ASCII
      expect(kBuildSignature, 0x5445524D);
    });

    test('kProviderSeed encodes EX continuation', () {
      expect(kProviderSeed, 0x4558);
    });
  });
}
