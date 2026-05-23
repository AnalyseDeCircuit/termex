import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/system/a11y/semantics_helpers.dart';

void main() {
  group('contrastRatio', () {
    test('black on white gives maximum contrast ~21', () {
      final ratio =
          contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF));
      expect(ratio, closeTo(21.0, 0.2));
    });

    test('white on white gives ratio 1.0', () {
      final ratio =
          contrastRatio(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF));
      expect(ratio, closeTo(1.0, 0.01));
    });

    test('symmetrical: fg/bg or bg/fg same result', () {
      const fg = Color(0xFF007AFF);
      const bg = Color(0xFFFFFFFF);
      expect(contrastRatio(fg, bg), closeTo(contrastRatio(bg, fg), 0.001));
    });
  });

  group('meetsWcagAA', () {
    test('black text on white passes AA', () {
      expect(
          meetsWcagAA(const Color(0xFF000000), const Color(0xFFFFFFFF)), isTrue);
    });

    test('light gray #CCCCCC on white fails AA', () {
      expect(
          meetsWcagAA(const Color(0xFFCCCCCC), const Color(0xFFFFFFFF)), isFalse);
    });

    test('#767676 on white passes large text threshold (3:1)', () {
      expect(
        meetsWcagAA(const Color(0xFF767676), const Color(0xFFFFFFFF),
            largeText: true),
        isTrue,
      );
    });

    test('dark theme textPrimary #E6EDF3 on bg #0D1117 passes AA', () {
      expect(
        meetsWcagAA(const Color(0xFFE6EDF3), const Color(0xFF0D1117)),
        isTrue,
      );
    });

    test('light scheme textPrimary #1F2328 on bg #F6F8FA passes AA', () {
      expect(
        meetsWcagAA(const Color(0xFF1F2328), const Color(0xFFF6F8FA)),
        isTrue,
      );
    });
  });

  group('asButton', () {
    testWidgets('wraps child with Semantics button=true', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: asButton(
            const SizedBox(width: 48, height: 48),
            label: '连接服务器',
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(Semantics).first);
      expect(semantics.label, '连接服务器');
    });
  });

  group('debugAssertMinTouch', () {
    test('does not throw for 44x44 size', () {
      final ctx = _FakeBuildContext();
      expect(
        () => debugAssertMinTouch(ctx, const Size(44, 44)),
        returnsNormally,
      );
    });

    test('does not throw for larger size', () {
      final ctx = _FakeBuildContext();
      expect(
        () => debugAssertMinTouch(ctx, const Size(80, 80)),
        returnsNormally,
      );
    });

    // flutter test always runs with asserts enabled (debug mode).
    test('throws AssertionError for 30x30 below min', () {
      final ctx = _FakeBuildContext();
      expect(
        () => debugAssertMinTouch(ctx, const Size(30, 30)),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

// Minimal BuildContext stand-in for non-widget tests.
class _FakeBuildContext extends Fake implements BuildContext {}
