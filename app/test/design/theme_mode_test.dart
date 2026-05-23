import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/design/tokens.dart';

void main() {
  group('TermexThemeMode', () {
    test('fromString parses all 4 modes', () {
      expect(TermexThemeMode.fromString('light'), TermexThemeMode.light);
      expect(TermexThemeMode.fromString('dark'), TermexThemeMode.dark);
      expect(TermexThemeMode.fromString('system'), TermexThemeMode.system);
      expect(TermexThemeMode.fromString('auto'), TermexThemeMode.auto);
    });

    test('fromString is case-insensitive', () {
      expect(TermexThemeMode.fromString('LIGHT'), TermexThemeMode.light);
      expect(TermexThemeMode.fromString('Auto'), TermexThemeMode.auto);
    });

    test('fromString defaults to system for unknown strings', () {
      expect(TermexThemeMode.fromString('unknown'), TermexThemeMode.system);
      expect(TermexThemeMode.fromString(''), TermexThemeMode.system);
    });

    test('toStorageString round-trips', () {
      for (final mode in TermexThemeMode.values) {
        expect(TermexThemeMode.fromString(mode.toStorageString()), mode);
      }
    });
  });

  group('resolveThemeData', () {
    test('light mode returns light theme', () {
      final data = resolveThemeData(TermexThemeMode.light, Brightness.dark);
      expect(data.colors.background, TermexColorScheme.light().background);
    });

    test('dark mode returns dark theme', () {
      final data = resolveThemeData(TermexThemeMode.dark, Brightness.light);
      expect(data.colors.background, TermexColorScheme.dark().background);
    });

    test('system mode follows platform brightness', () {
      final light = resolveThemeData(TermexThemeMode.system, Brightness.light);
      expect(light.colors.background, TermexColorScheme.light().background);

      final dark = resolveThemeData(TermexThemeMode.system, Brightness.dark);
      expect(dark.colors.background, TermexColorScheme.dark().background);
    });
  });

  group('TermexThemeData', () {
    test('dark() factory constructs without error', () {
      final data = TermexThemeData.dark();
      expect(data.colors, isNotNull);
    });

    test('light() factory constructs without error', () {
      final data = TermexThemeData.light();
      expect(data.colors, isNotNull);
    });

    test('equality based on colors', () {
      expect(TermexThemeData.dark(), equals(TermexThemeData.dark()));
      expect(TermexThemeData.light(), equals(TermexThemeData.light()));
      expect(TermexThemeData.dark(), isNot(equals(TermexThemeData.light())));
    });
  });
}
