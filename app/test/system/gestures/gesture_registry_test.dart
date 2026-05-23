import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/system/gestures/gesture_registry.dart';

void main() {
  group('compareGesturePriority', () {
    test('tap beats longPress', () {
      expect(compareGesturePriority(GestureKind.tap, GestureKind.longPress), -1);
    });

    test('longPress beats pan', () {
      expect(compareGesturePriority(GestureKind.longPress, GestureKind.pan), -1);
    });

    test('pan beats scale', () {
      expect(compareGesturePriority(GestureKind.pan, GestureKind.scale), -1);
    });

    test('scale beats scroll', () {
      expect(compareGesturePriority(GestureKind.scale, GestureKind.scroll), -1);
    });

    test('equal kinds return 0', () {
      expect(compareGesturePriority(GestureKind.tap, GestureKind.tap), 0);
    });

    test('scroll loses to tap', () {
      expect(compareGesturePriority(GestureKind.scroll, GestureKind.tap), 1);
    });
  });

  group('resolveConflict', () {
    test('always returns higher priority gesture', () {
      expect(resolveConflict(GestureKind.tap, GestureKind.scroll), GestureKind.tap);
      expect(resolveConflict(GestureKind.scroll, GestureKind.tap), GestureKind.tap);
      expect(resolveConflict(GestureKind.pan, GestureKind.longPress), GestureKind.longPress);
    });
  });

  group('LongPressPanGuard', () {
    test('pan not suppressed before long press', () {
      final guard = LongPressPanGuard();
      expect(guard.isPanSuppressed, isFalse);
    });

    test('pan suppressed immediately after long press', () {
      final guard = LongPressPanGuard();
      guard.onLongPressTriggered();
      expect(guard.isPanSuppressed, isTrue);
    });

    test('reset clears suppression', () {
      final guard = LongPressPanGuard();
      guard.onLongPressTriggered();
      guard.reset();
      expect(guard.isPanSuppressed, isFalse);
    });
  });

  group('isPinchRecognized', () {
    test('exact 1.0 scale not recognized', () {
      expect(isPinchRecognized(1.0), isFalse);
    });

    test('scale 1.04 below threshold', () {
      expect(isPinchRecognized(1.04), isFalse);
    });

    test('scale 1.05 at threshold — recognized', () {
      expect(isPinchRecognized(1.05), isTrue);
    });

    test('scale 1.1 above threshold — recognized', () {
      expect(isPinchRecognized(1.1), isTrue);
    });

    test('pinch-in below inverse threshold — recognized', () {
      expect(isPinchRecognized(1.0 / 1.05), isTrue);
    });
  });

  group('EdgeSwipeRegistry', () {
    test('enabled by default', () {
      expect(EdgeSwipeRegistry().isEdgeSwipeEnabled, isTrue);
    });

    test('disabled when hardware keyboard connected', () {
      final reg = EdgeSwipeRegistry();
      reg.onHardwareKeyboardChanged(true);
      expect(reg.isEdgeSwipeEnabled, isFalse);
    });

    test('disabled when user disables it', () {
      final reg = EdgeSwipeRegistry();
      reg.setUserDisabled(true);
      expect(reg.isEdgeSwipeEnabled, isFalse);
    });

    test('re-enabled when keyboard disconnected', () {
      final reg = EdgeSwipeRegistry();
      reg.onHardwareKeyboardChanged(true);
      reg.onHardwareKeyboardChanged(false);
      expect(reg.isEdgeSwipeEnabled, isTrue);
    });
  });

  group('GestureRegistry', () {
    setUp(() => GestureRegistry.reset());

    test('all kinds enabled by default', () {
      for (final kind in GestureKind.values) {
        expect(GestureRegistry.isEnabled(kind), isTrue,
            reason: '${kind.name} should be enabled by default');
      }
    });

    test('disable/enable round-trips', () {
      GestureRegistry.disable(GestureKind.scale);
      expect(GestureRegistry.isEnabled(GestureKind.scale), isFalse);
      GestureRegistry.enable(GestureKind.scale);
      expect(GestureRegistry.isEnabled(GestureKind.scale), isTrue);
    });

    test('onLongPressStart suppresses pan', () {
      GestureRegistry.onLongPressStart();
      expect(GestureRegistry.isEnabled(GestureKind.pan), isFalse);
    });

    test('onHardwareKeyboardChanged(true) disables pan', () {
      GestureRegistry.onHardwareKeyboardChanged(true);
      expect(GestureRegistry.isEnabled(GestureKind.pan), isFalse);
    });

    test('onHardwareKeyboardChanged(false) re-enables pan', () {
      GestureRegistry.onHardwareKeyboardChanged(true);
      GestureRegistry.onHardwareKeyboardChanged(false);
      expect(GestureRegistry.isEnabled(GestureKind.pan), isTrue);
    });
  });
}
