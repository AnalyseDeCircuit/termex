import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/design/tokens.dart';

import 'test_helpers.dart';

void main() {
  group('TermexThemeMode.fromString', () {
    test('parses "light"', () {
      expect(TermexThemeMode.fromString('light'), TermexThemeMode.light);
    });

    test('parses "dark"', () {
      expect(TermexThemeMode.fromString('dark'), TermexThemeMode.dark);
    });

    test('parses "system"', () {
      expect(TermexThemeMode.fromString('system'), TermexThemeMode.system);
    });

    test('defaults unknown string to system', () {
      expect(TermexThemeMode.fromString('rainbow'), TermexThemeMode.system);
    });
  });

  group('TermexThemeData', () {
    test('dark() uses dark color scheme', () {
      final theme = TermexThemeData.dark();
      expect(theme.colors.background, equals(const Color(0xFF0D1117)));
    });

    test('light() uses light color scheme', () {
      final theme = TermexThemeData.light();
      expect(theme.colors.background, equals(const Color(0xFFF6F8FA)));
    });

    test('equality based on colors', () {
      expect(TermexThemeData.dark(), equals(TermexThemeData.dark()));
      expect(TermexThemeData.light(), isNot(equals(TermexThemeData.dark())));
    });
  });

  group('TermexThemeScope', () {
    testWidgets('provides theme to descendants', (tester) async {
      TermexThemeData? captured;
      await tester.pumpWidget(wrapWidget(
        Builder(builder: (ctx) {
          captured = TermexThemeScope.of(ctx);
          return const SizedBox();
        }),
        theme: TermexThemeData.dark(),
      ));
      expect(captured, isNotNull);
      expect(captured!.colors.background, equals(const Color(0xFF0D1117)));
    });

    testWidgets('light theme has lighter background', (tester) async {
      TermexThemeData? captured;
      await tester.pumpWidget(wrapWidget(
        Builder(builder: (ctx) {
          captured = TermexThemeScope.of(ctx);
          return const SizedBox();
        }),
        theme: TermexThemeData.light(),
      ));
      expect(captured!.colors.background, equals(const Color(0xFFF6F8FA)));
    });
  });

  group('ThemeModeNotifier', () {
    testWidgets('starts in system mode', (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(builder: (ctx, ref, _) {
            capturedRef = ref;
            return const SizedBox();
          }),
        ),
      );
      expect(capturedRef.read(themeModeProvider), TermexThemeMode.system);
    });

    testWidgets('setMode updates provider', (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(builder: (ctx, ref, _) {
            capturedRef = ref;
            return const SizedBox();
          }),
        ),
      );
      capturedRef.read(themeModeProvider.notifier).setMode(TermexThemeMode.dark);
      expect(capturedRef.read(themeModeProvider), TermexThemeMode.dark);
    });
  });
}
