/// Pins the behaviour behind "选择浅色主题没有任何变化".
///
/// The theme plumbing (`themeModeProvider` → `themeDataProvider` →
/// `TermexThemeScope`) resolved a light [TermexColorScheme] correctly all
/// along. What never changed was the pixels: every widget painted from the
/// `TermexColors` *constants*, which are the dark palette compiled in. So
/// switching to Light updated the scope and repainted nothing.
///
/// These tests assert the two properties that make a switch actually
/// visible: colours resolve from the scope, and changing the scope rebuilds
/// the readers — including `const` widgets, which is the case a plain
/// global mutable would miss.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/design/tokens.dart';

/// Deliberately `const`-constructible and takes no colour argument: when the
/// theme flips, Flutter sees an identical widget instance and would skip the
/// rebuild entirely if this widget did not depend on the scope.
class _ConstSwatch extends StatelessWidget {
  const _ConstSwatch();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: context.colors.backgroundPrimary);
}

Color _swatchColor(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byType(ColoredBox)).color;

void main() {
  group('context.colors', () {
    testWidgets('resolves from the enclosing scope', (tester) async {
      await tester.pumpWidget(TermexThemeScope(
        theme: TermexThemeData.light(),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: _ConstSwatch(),
        ),
      ));
      expect(_swatchColor(tester), TermexColorScheme.light().backgroundPrimary);
    });

    // Widget tests routinely pump a bare MaterialApp with no Termex scope.
    // Those must keep rendering in the default palette rather than crashing.
    testWidgets('falls back to dark with no scope', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: _ConstSwatch(),
      ));
      expect(_swatchColor(tester), TermexColorScheme.dark().backgroundPrimary);
    });

    testWidgets('a const reader repaints when the scope changes',
        (tester) async {
      Widget app(TermexThemeData theme) => TermexThemeScope(
            theme: theme,
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: _ConstSwatch(),
            ),
          );

      await tester.pumpWidget(app(TermexThemeData.dark()));
      expect(_swatchColor(tester), TermexColorScheme.dark().backgroundPrimary);

      await tester.pumpWidget(app(TermexThemeData.light()));
      await tester.pump();
      expect(_swatchColor(tester), TermexColorScheme.light().backgroundPrimary);
    });
  });

  group('themeModeProvider drives the scope', () {
    testWidgets('switching to light flips the painted colour',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const TermexThemeProvider(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: _ConstSwatch(),
          ),
        ),
      ));

      // Default is `system`; the provider's platform brightness defaults to
      // dark, so the app starts dark.
      expect(_swatchColor(tester), TermexColorScheme.dark().backgroundPrimary);

      container.read(themeModeProvider.notifier).setMode(TermexThemeMode.light);
      await tester.pump();
      expect(_swatchColor(tester), TermexColorScheme.light().backgroundPrimary);

      container.read(themeModeProvider.notifier).setMode(TermexThemeMode.dark);
      await tester.pump();
      expect(_swatchColor(tester), TermexColorScheme.dark().backgroundPrimary);
    });

    testWidgets('system mode follows the OS brightness', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const TermexThemeProvider(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: _ConstSwatch(),
          ),
        ),
      ));

      container
          .read(themeModeProvider.notifier)
          .setMode(TermexThemeMode.system);
      container.read(platformBrightnessProvider.notifier).state =
          Brightness.light;
      await tester.pump();
      expect(_swatchColor(tester), TermexColorScheme.light().backgroundPrimary);
    });
  });

  group('TermexColorScheme', () {
    // The migration swaps the receiver only (TermexColors.x →
    // context.colors.x), so every constant must have a same-named field.
    test('exposes a field for every TermexColors constant', () {
      final dark = TermexColorScheme.dark();
      expect(dark.backgroundPrimary, TermexColors.backgroundPrimary);
      expect(dark.backgroundSecondary, TermexColors.backgroundSecondary);
      expect(dark.backgroundTertiary, TermexColors.backgroundTertiary);
      expect(dark.primary, TermexColors.primary);
      expect(dark.success, TermexColors.success);
      expect(dark.warning, TermexColors.warning);
      expect(dark.danger, TermexColors.danger);
      expect(dark.neutral, TermexColors.neutral);
      expect(dark.textPrimary, TermexColors.textPrimary);
      expect(dark.textSecondary, TermexColors.textSecondary);
      expect(dark.textMuted, TermexColors.textMuted);
      expect(dark.border, TermexColors.border);
      expect(dark.borderFocus, TermexColors.borderFocus);
    });

    test('light and dark differ on every surface and text colour', () {
      final light = TermexColorScheme.light();
      final dark = TermexColorScheme.dark();
      expect(light, isNot(equals(dark)));
      for (final pair in [
        [light.backgroundPrimary, dark.backgroundPrimary],
        [light.backgroundSecondary, dark.backgroundSecondary],
        [light.backgroundTertiary, dark.backgroundTertiary],
        [light.textPrimary, dark.textPrimary],
        [light.textSecondary, dark.textSecondary],
        [light.textMuted, dark.textMuted],
        [light.border, dark.border],
      ]) {
        expect(pair[0], isNot(equals(pair[1])));
      }
    });
  });
}
