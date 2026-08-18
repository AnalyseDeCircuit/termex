import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import '../../design/mobile_tokens.dart';

// Wraps a widget with a Semantics node carrying a required label.
Widget semanticLabel({
  required String label,
  required Widget child,
  bool button = false,
  bool header = false,
  bool image = false,
}) {
  return Semantics(
    label: label,
    button: button,
    header: header,
    image: image,
    child: child,
  );
}

// Ensures the widget meets the 44pt minimum touch target (iOS HIG / WCAG 2.5.5).
Widget withMinTouchTarget({
  required Widget child,
  double size = MobileTokens.minTouchTarget,
  AlignmentGeometry alignment = Alignment.center,
}) {
  return ConstrainedBox(
    constraints: BoxConstraints(
      minWidth: size,
      minHeight: size,
    ),
    child: Align(alignment: alignment, child: child),
  );
}

// Wraps a widget as an accessible button with label, hint, and optional tap.
Widget asButton(
  Widget child, {
  required String label,
  String? hint,
  VoidCallback? onTap,
}) {
  return Semantics(
    button: true,
    label: label,
    hint: hint,
    onTap: onTap,
    child: child,
  );
}

// Asserts that the widget's rendered size meets the 44pt minimum touch target.
// No-op in release builds.
void debugAssertMinTouch(BuildContext ctx, Size size) {
  assert(
    size.width >= MobileTokens.minTouchTarget &&
        size.height >= MobileTokens.minTouchTarget,
    'Touch target $size is below the 44pt minimum (iOS HIG / WCAG 2.5.5).',
  );
}

// Computes WCAG contrast ratio between two colors.
// Returns a value in [1.0, 21.0].
double contrastRatio(Color foreground, Color background) {
  final fL = _relativeLuminance(foreground);
  final bL = _relativeLuminance(background);
  final lighter = fL > bL ? fL : bL;
  final darker = fL > bL ? bL : fL;
  return (lighter + 0.05) / (darker + 0.05);
}

// WCAG AA requires 4.5:1 for normal text, 3:1 for large text.
bool meetsWcagAA(Color foreground, Color background, {bool largeText = false}) {
  final ratio = contrastRatio(foreground, background);
  return largeText ? ratio >= 3.0 : ratio >= 4.5;
}

double _relativeLuminance(Color c) {
  double linearize(double channel) {
    return channel <= 0.04045
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = linearize(c.r);
  final g = linearize(c.g);
  final b = linearize(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
