import 'package:flutter/services.dart';

/// Simplified haptic feedback API for mobile Termex interactions.
///
/// Maps common UI events to the appropriate platform vibration intensity.
/// Delegates to [HapticFeedback] from flutter/services; no-ops silently on
/// platforms that do not support haptics (macOS, Linux, Windows).
abstract final class Haptics {
  /// SSH connect success, save success. Light impact.
  static Future<void> success() => HapticFeedback.lightImpact();

  /// Dangerous command detection, destructive action warning. Medium impact.
  static Future<void> warning() => HapticFeedback.mediumImpact();

  /// SSH connect failure, authentication error. Heavy impact.
  static Future<void> error() => HapticFeedback.heavyImpact();

  /// List item selection, Tab switch, text copy. Selection click.
  static Future<void> select() => HapticFeedback.selectionClick();

  /// Pinch-to-Zoom reaches the font size boundary (8 px or 28 px). Heavy impact.
  static Future<void> zoomBound() => HapticFeedback.heavyImpact();
}
