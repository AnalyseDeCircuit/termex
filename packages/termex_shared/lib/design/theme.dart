import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'colors.dart';
import 'typography.dart';
import 'spacing.dart';
import 'radius.dart';
import 'elevation.dart';
import 'animations.dart';

enum TermexThemeMode {
  light,
  dark,
  system,
  /// Alias of [system] kept for legacy storage values written by the
  /// Tauri/Vue build, which used `"auto"`. Resolves identically.
  auto;

  static TermexThemeMode fromString(String s) {
    switch (s.toLowerCase()) {
      case 'light':
        return TermexThemeMode.light;
      case 'dark':
        return TermexThemeMode.dark;
      case 'auto':
        return TermexThemeMode.auto;
      case 'system':
        return TermexThemeMode.system;
      default:
        return TermexThemeMode.system;
    }
  }

  /// Canonical lowercase identifier used to persist this mode.
  String toStorageString() {
    switch (this) {
      case TermexThemeMode.light:
        return 'light';
      case TermexThemeMode.dark:
        return 'dark';
      case TermexThemeMode.system:
        return 'system';
      case TermexThemeMode.auto:
        return 'auto';
    }
  }
}

/// Resolves a [TermexThemeMode] + platform [Brightness] into concrete
/// [TermexThemeData]. `system` / `auto` follow the platform; `light` /
/// `dark` ignore the platform and return the corresponding factory.
TermexThemeData resolveThemeData(
  TermexThemeMode mode,
  Brightness platformBrightness,
) {
  switch (mode) {
    case TermexThemeMode.light:
      return TermexThemeData.light();
    case TermexThemeMode.dark:
      return TermexThemeData.dark();
    case TermexThemeMode.system:
    case TermexThemeMode.auto:
      return platformBrightness == Brightness.dark
          ? TermexThemeData.dark()
          : TermexThemeData.light();
  }
}

@immutable
class TermexThemeData {
  final TermexColorScheme colors;
  final TermexTypographyRef typography;
  final TermexSpacingRef spacing;
  final TermexRadiusRef radius;
  final TermexElevationRef elevation;
  final AppAnimationsRef animations;

  const TermexThemeData({
    required this.colors,
    required this.typography,
    required this.spacing,
    required this.radius,
    required this.elevation,
    required this.animations,
  });

  factory TermexThemeData.dark() => TermexThemeData(
        colors: TermexColorScheme.dark(),
        typography: const TermexTypographyRef(),
        spacing: const TermexSpacingRef(),
        radius: const TermexRadiusRef(),
        elevation: const TermexElevationRef(),
        animations: const AppAnimationsRef(),
      );

  factory TermexThemeData.light() => TermexThemeData(
        colors: TermexColorScheme.light(),
        typography: const TermexTypographyRef(),
        spacing: const TermexSpacingRef(),
        radius: const TermexRadiusRef(),
        elevation: const TermexElevationRef(),
        animations: const AppAnimationsRef(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TermexThemeData && colors == other.colors;

  @override
  int get hashCode => colors.hashCode;
}

@immutable
class TermexTypographyRef {
  const TermexTypographyRef();

  TextStyle get heading1 => TermexTypography.heading1;
  TextStyle get heading2 => TermexTypography.heading2;
  TextStyle get heading3 => TermexTypography.heading3;
  TextStyle get heading4 => TermexTypography.heading4;
  TextStyle get body => TermexTypography.body;
  TextStyle get bodySmall => TermexTypography.bodySmall;
  TextStyle get caption => TermexTypography.caption;
  TextStyle get monospace => TermexTypography.monospace;
}

@immutable
class TermexSpacingRef {
  const TermexSpacingRef();

  double get xs => TermexSpacing.xs;
  double get sm => TermexSpacing.sm;
  double get md => TermexSpacing.md;
  double get lg => TermexSpacing.lg;
  double get xl => TermexSpacing.xl;
  double get xxl => TermexSpacing.xxl;
  double get xxxl => TermexSpacing.xxxl;
}

@immutable
class TermexRadiusRef {
  const TermexRadiusRef();

  BorderRadius get none => TermexRadius.none;
  BorderRadius get sm => TermexRadius.sm;
  BorderRadius get md => TermexRadius.md;
  BorderRadius get lg => TermexRadius.lg;
  BorderRadius get full => TermexRadius.full;
}

@immutable
class TermexElevationRef {
  const TermexElevationRef();

  List<BoxShadow> get e0 => TermexElevation.e0;
  List<BoxShadow> get e1 => TermexElevation.e1;
  List<BoxShadow> get e2 => TermexElevation.e2;
  List<BoxShadow> get e3 => TermexElevation.e3;
}

@immutable
class AppAnimationsRef {
  const AppAnimationsRef();

  Duration get dialogOpen => AppAnimations.dialogOpen;
  Duration get dialogClose => AppAnimations.dialogClose;
  Duration get dialogOverlay => AppAnimations.dialogOverlay;
  Duration get toastEnter => AppAnimations.toastEnter;
  Duration get toastExit => AppAnimations.toastExit;
  Duration get popoverEnter => AppAnimations.popoverEnter;
  Duration get popoverExit => AppAnimations.popoverExit;
  Duration get pageEnter => AppAnimations.pageEnter;
  Duration get pageExit => AppAnimations.pageExit;
  Duration get listItemEnter => AppAnimations.listItemEnter;
  Duration get fast => AppAnimations.fast;
  Duration get normal => AppAnimations.normal;
  Duration get slow => AppAnimations.slow;

  Curve get dialogOpenCurve => AppAnimations.dialogOpenCurve;
  Curve get dialogCloseCurve => AppAnimations.dialogCloseCurve;
  Curve get popoverEnterCurve => AppAnimations.popoverEnterCurve;
  Curve get pageCurve => AppAnimations.pageCurve;
  Curve get standardEasing => AppAnimations.standardEasing;
  Curve get exitEasing => AppAnimations.exitEasing;
}
