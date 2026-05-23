import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/design/colors.dart';

// WCAG AA contrast ratio threshold for normal text (4.5:1).
const double kWcagAA = 4.5;
// WCAG AA contrast ratio threshold for large text (3.0:1).
const double kWcagAALarge = 3.0;

/// Relative luminance of a sRGB colour component (IEC 61966-2-1).
double _linearise(double c) =>
    c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) * ((c + 0.055) / 1.055);

double _luminance(int argb) {
  final r = _linearise(((argb >> 16) & 0xFF) / 255.0);
  final g = _linearise(((argb >> 8) & 0xFF) / 255.0);
  final b = _linearise((argb & 0xFF) / 255.0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(int fg, int bg) {
  final lf = _luminance(fg);
  final lb = _luminance(bg);
  final lighter = lf > lb ? lf : lb;
  final darker = lf > lb ? lb : lf;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // ─── luminance helper ────────────────────────────────────────────────────────

  test('pure white has luminance 1.0', () {
    expect(_luminance(0xFFFFFF), closeTo(1.0, 0.001));
  });

  test('pure black has luminance 0.0', () {
    expect(_luminance(0x000000), closeTo(0.0, 0.001));
  });

  test('black-on-white contrast is 21:1', () {
    expect(contrastRatio(0x000000, 0xFFFFFF), closeTo(21.0, 0.1));
  });

  // ─── Dark theme token contrast checks ────────────────────────────────────────

  group('Dark theme WCAG AA contrast', () {
    test('textPrimary on background meets 4.5:1', () {
      final ratio = contrastRatio(
        TermexColors.textPrimary.toARGB32() & 0xFFFFFF,
        TermexColors.backgroundPrimary.toARGB32() & 0xFFFFFF,
      );
      expect(ratio, greaterThanOrEqualTo(kWcagAA),
          reason:
              'textPrimary (#${(TermexColors.textPrimary.toARGB32() & 0xFFFFFF).toRadixString(16)}) '
              'on background (#${(TermexColors.backgroundPrimary.toARGB32() & 0xFFFFFF).toRadixString(16)}) '
              'contrast $ratio < $kWcagAA');
    });

    test('primary colour on background meets 3.0:1 (large text)', () {
      final ratio = contrastRatio(
        TermexColors.primary.toARGB32() & 0xFFFFFF,
        TermexColors.backgroundPrimary.toARGB32() & 0xFFFFFF,
      );
      expect(ratio, greaterThanOrEqualTo(kWcagAALarge),
          reason: 'primary on background contrast $ratio < $kWcagAALarge');
    });

    test('success colour on background meets 3.0:1', () {
      final ratio = contrastRatio(
        TermexColors.success.toARGB32() & 0xFFFFFF,
        TermexColors.backgroundPrimary.toARGB32() & 0xFFFFFF,
      );
      expect(ratio, greaterThanOrEqualTo(kWcagAALarge));
    });

    test('danger colour on background meets 3.0:1', () {
      final ratio = contrastRatio(
        TermexColors.danger.toARGB32() & 0xFFFFFF,
        TermexColors.backgroundPrimary.toARGB32() & 0xFFFFFF,
      );
      expect(ratio, greaterThanOrEqualTo(kWcagAALarge));
    });

    test('warning colour on background meets 3.0:1', () {
      final ratio = contrastRatio(
        TermexColors.warning.toARGB32() & 0xFFFFFF,
        TermexColors.backgroundPrimary.toARGB32() & 0xFFFFFF,
      );
      expect(ratio, greaterThanOrEqualTo(kWcagAALarge));
    });

    test('textSecondary on backgroundSecondary meets 3.0:1', () {
      final ratio = contrastRatio(
        TermexColors.textSecondary.toARGB32() & 0xFFFFFF,
        TermexColors.backgroundSecondary.toARGB32() & 0xFFFFFF,
      );
      expect(ratio, greaterThanOrEqualTo(kWcagAALarge));
    });

    test('textPrimary on backgroundSecondary meets 4.5:1', () {
      final ratio = contrastRatio(
        TermexColors.textPrimary.toARGB32() & 0xFFFFFF,
        TermexColors.backgroundSecondary.toARGB32() & 0xFFFFFF,
      );
      expect(ratio, greaterThanOrEqualTo(kWcagAA));
    });

    test('textPrimary on backgroundTertiary meets 4.5:1', () {
      final ratio = contrastRatio(
        TermexColors.textPrimary.toARGB32() & 0xFFFFFF,
        TermexColors.backgroundTertiary.toARGB32() & 0xFFFFFF,
      );
      expect(ratio, greaterThanOrEqualTo(kWcagAA));
    });
  });

  // ─── contrastRatio symmetry ──────────────────────────────────────────────────

  test('contrastRatio is symmetric', () {
    final a = contrastRatio(0xE6EDF3, 0x0D1117);
    final b = contrastRatio(0x0D1117, 0xE6EDF3);
    expect(a, closeTo(b, 0.001));
  });
}
