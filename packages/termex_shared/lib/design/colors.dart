import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show BuildContext;

import 'inherited_theme.dart';

/// Dark-palette constants.
///
/// **Do not read these from widget code.** They are the raw dark values and
/// ignore the active theme entirely — reading them is exactly why selecting
/// "Light" in Settings used to change nothing. Widgets must resolve colours
/// through the active [TermexColorScheme]: `context.colors.textPrimary`
/// inside a build method, or an injected `TermexColorScheme` in painters and
/// other context-free code.
///
/// These stay as the source of truth for [TermexColorScheme.dark] and for
/// the handful of places that legitimately need a fixed palette regardless
/// of theme (e.g. the pre-first-frame splash, which paints before any
/// [TermexThemeScope] exists).
abstract final class TermexColors {
  static const Color backgroundPrimary = Color(0xFF0D1117);
  static const Color backgroundSecondary = Color(0xFF161B22);
  static const Color backgroundTertiary = Color(0xFF21262D);

  static const Color primary = Color(0xFF2F81F7);
  static const Color success = Color(0xFF3FB950);
  static const Color warning = Color(0xFFD29922);
  static const Color danger = Color(0xFFF85149);
  static const Color neutral = Color(0xFF8B949E);

  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF7D8590);
  static const Color textMuted = Color(0xFF484F58);

  static const Color border = Color(0xFF30363D);
  static const Color borderFocus = Color(0xFF2F81F7);
}

/// Resolves the active palette from the enclosing [TermexThemeScope].
///
/// This is the replacement for reading [TermexColors] directly: it depends
/// on the scope, so a theme switch marks the reading element dirty and
/// rebuilds it — including `const` widgets, which a plain global would
/// silently leave painted in the old palette.
extension TermexColorsContext on BuildContext {
  TermexColorScheme get colors => TermexThemeScope.of(this).colors;
}

@immutable
class TermexColorScheme {
  final Color primary;
  final Color onPrimary;
  final Color surface;
  final Color onSurface;
  final Color background;
  final Color onBackground;

  /// Field names below deliberately mirror [TermexColors] one-for-one so a
  /// widget migrates by swapping the receiver (`TermexColors.x` →
  /// `context.colors.x`) with no renaming.
  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color backgroundTertiary;
  final Color error;
  final Color onError;
  final Color success;
  final Color warning;
  final Color danger;
  final Color neutral;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderFocus;

  const TermexColorScheme({
    required this.primary,
    required this.onPrimary,
    required this.surface,
    required this.onSurface,
    required this.background,
    required this.onBackground,
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.backgroundTertiary,
    required this.error,
    required this.onError,
    required this.success,
    required this.warning,
    required this.danger,
    required this.neutral,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderFocus,
  });

  factory TermexColorScheme.dark() => const TermexColorScheme(
        primary: Color(0xFF2F81F7),
        onPrimary: Color(0xFFFFFFFF),
        surface: Color(0xFF161B22),
        onSurface: Color(0xFFE6EDF3),
        background: Color(0xFF0D1117),
        onBackground: Color(0xFFE6EDF3),
        backgroundPrimary: Color(0xFF0D1117),
        backgroundSecondary: Color(0xFF161B22),
        backgroundTertiary: Color(0xFF21262D),
        error: Color(0xFFF85149),
        onError: Color(0xFFFFFFFF),
        success: Color(0xFF3FB950),
        warning: Color(0xFFD29922),
        danger: Color(0xFFF85149),
        neutral: Color(0xFF8B949E),
        textPrimary: Color(0xFFE6EDF3),
        textSecondary: Color(0xFF7D8590),
        textMuted: Color(0xFF484F58),
        border: Color(0xFF30363D),
        borderFocus: Color(0xFF2F81F7),
      );

  factory TermexColorScheme.light() => const TermexColorScheme(
        primary: Color(0xFF0969DA),
        onPrimary: Color(0xFFFFFFFF),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF1F2328),
        background: Color(0xFFF6F8FA),
        onBackground: Color(0xFF1F2328),
        backgroundPrimary: Color(0xFFF6F8FA),
        backgroundSecondary: Color(0xFFFFFFFF),
        backgroundTertiary: Color(0xFFEAEEF2),
        error: Color(0xFFCF222E),
        onError: Color(0xFFFFFFFF),
        success: Color(0xFF1A7F37),
        warning: Color(0xFF9A6700),
        danger: Color(0xFFCF222E),
        neutral: Color(0xFF6E7781),
        textPrimary: Color(0xFF1F2328),
        textSecondary: Color(0xFF656D76),
        textMuted: Color(0xFF9198A1),
        border: Color(0xFFD0D7DE),
        borderFocus: Color(0xFF0969DA),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TermexColorScheme &&
          primary == other.primary &&
          onPrimary == other.onPrimary &&
          surface == other.surface &&
          onSurface == other.onSurface &&
          background == other.background &&
          onBackground == other.onBackground &&
          backgroundPrimary == other.backgroundPrimary &&
          backgroundSecondary == other.backgroundSecondary &&
          backgroundTertiary == other.backgroundTertiary &&
          error == other.error &&
          onError == other.onError &&
          success == other.success &&
          warning == other.warning &&
          danger == other.danger &&
          neutral == other.neutral &&
          textPrimary == other.textPrimary &&
          textSecondary == other.textSecondary &&
          textMuted == other.textMuted &&
          border == other.border &&
          borderFocus == other.borderFocus;

  @override
  int get hashCode => Object.hashAll([
        primary,
        onPrimary,
        surface,
        onSurface,
        background,
        onBackground,
        backgroundPrimary,
        backgroundSecondary,
        backgroundTertiary,
        error,
        onError,
        success,
        warning,
        danger,
        neutral,
        textPrimary,
        textSecondary,
        textMuted,
        border,
        borderFocus,
      ]);
}
