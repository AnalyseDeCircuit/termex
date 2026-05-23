import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/system/haptic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        log.add(call);
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('HapticType enum', () {
    test('has all 6 expected types', () {
      expect(HapticType.values.length, 6);
      expect(HapticType.values, contains(HapticType.selectionLight));
      expect(HapticType.values, contains(HapticType.successMedium));
      expect(HapticType.values, contains(HapticType.warningHeavy));
      expect(HapticType.values, contains(HapticType.errorRigid));
      expect(HapticType.values, contains(HapticType.zoomBound));
      expect(HapticType.values, contains(HapticType.longPressStart));
    });
  });

  group('TermexHaptic.trigger', () {
    test('all types call platform channel without throwing', () async {
      for (final type in HapticType.values) {
        await TermexHaptic.trigger(type);
      }
      expect(log, isNotEmpty);
    });

    test('convenience wrappers each trigger one platform call', () async {
      await TermexHaptic.selectionLight();
      await TermexHaptic.successMedium();
      await TermexHaptic.warningHeavy();
      await TermexHaptic.errorRigid();
      await TermexHaptic.zoomBound();
      await TermexHaptic.longPressStart();
      expect(log.length, 6);
    });
  });
}
