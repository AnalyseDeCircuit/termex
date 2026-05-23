import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/system/keyboard/hardware_keyboard_detector.dart';

import '../../widget/test_helpers.dart';

void main() {
  group('HardwareKeyboardDetector', () {
    testWidgets('initially reports isConnected=false', (tester) async {
      bool? lastValue;
      await tester.pumpWidget(wrapWidget(
        HardwareKeyboardDetector(
          builder: (ctx, connected) {
            lastValue = connected;
            return const SizedBox.shrink();
          },
        ),
      ));
      expect(lastValue, isFalse);
    });

    testWidgets('reports isConnected=true after hardware key event', (tester) async {
      bool? lastValue;
      await tester.pumpWidget(wrapWidget(
        HardwareKeyboardDetector(
          builder: (ctx, connected) {
            lastValue = connected;
            return const SizedBox.shrink();
          },
        ),
      ));

      // Simulate a hardware key down event.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(lastValue, isTrue);
    });
  });

  group('HardwareKeyboardNotifier', () {
    test('initially isConnected=false', () {
      final notifier = HardwareKeyboardNotifier();
      expect(notifier.isConnected, isFalse);
      notifier.dispose();
    });
  });
}
