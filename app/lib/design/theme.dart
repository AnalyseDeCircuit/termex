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
  system;

  static TermexThemeMode fromString(String s) {
    switch (s.toLowerCase()) {
      case 'light':
        return TermexThemeMode.light;
      case 'dark':
        return TermexThemeMode.dark;
      case 'system':
      default:
        return TermexThemeMode.system;
    }
  }
}

@immutable
class TermexThemeData {
  final TermexColorScheme colors;
  final _TermexTypographyRef typography;
  final _TermexSpacingRef spacing;
  final _TermexRadiusRef radius;
  final _TermexElevationRef elevation;
  final _AppAnimationsRef animations;

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
        typography: const _TermexTypographyRef(),
        spacing: const _TermexSpacingRef(),
        radius: const _TermexRadiusRef(),
        elevation: const _TermexElevationRef(),
        animations: const _AppAnimationsRef(),
      );

  factory TermexThemeData.light() => TermexThemeData(
        colors: TermexColorScheme.light(),
        typography: const _TermexTypographyRef(),
        spacing: const _TermexSpacingRef(),
        radius: const _TermexRadiusRef(),
        elevation: const _TermexElevationRef(),
        animations: const _AppAnimationsRef(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TermexThemeData && colors == other.colors;

  @override
  int get hashCode => colors.hashCode;
}

@immutable
class _TermexTypographyRef {
  const _TermexTypographyRef();

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
class _TermexSpacingRef {
  const _TermexSpacingRef();

  double get xs => TermexSpacing.xs;
  double get sm => TermexSpacing.sm;
  double get md => TermexSpacing.md;
  double get lg => TermexSpacing.lg;
  double get xl => TermexSpacing.xl;
  double get xxl => TermexSpacing.xxl;
  double get xxxl => TermexSpacing.xxxl;
}

@immutable
class _TermexRadiusRef {
  const _TermexRadiusRef();

  BorderRadius get none => TermexRadius.none;
  BorderRadius get sm => TermexRadius.sm;
  BorderRadius get md => TermexRadius.md;
  BorderRadius get lg => TermexRadius.lg;
  BorderRadius get full => TermexRadius.full;
}

@immutable
class _TermexElevationRef {
  const _TermexElevationRef();

  List<BoxShadow> get e0 => TermexElevation.e0;
  List<BoxShadow> get e1 => TermexElevation.e1;
  List<BoxShadow> get e2 => TermexElevation.e2;
  List<BoxShadow> get e3 => TermexElevation.e3;
}

@immutable
class _AppAnimationsRef {
  const _AppAnimationsRef();

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
