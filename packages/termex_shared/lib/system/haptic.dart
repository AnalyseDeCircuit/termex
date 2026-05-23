import 'package:flutter/services.dart';

enum HapticType {
  selectionLight,
  successMedium,
  warningHeavy,
  errorRigid,
  zoomBound,
  longPressStart,
}

abstract final class TermexHaptic {
  static Future<void> trigger(HapticType type) async {
    switch (type) {
      case HapticType.selectionLight:
        await HapticFeedback.selectionClick();
      case HapticType.successMedium:
        await HapticFeedback.mediumImpact();
      case HapticType.warningHeavy:
        await HapticFeedback.heavyImpact();
      case HapticType.errorRigid:
        await HapticFeedback.vibrate();
      case HapticType.zoomBound:
        await HapticFeedback.lightImpact();
      case HapticType.longPressStart:
        await HapticFeedback.lightImpact();
    }
  }

  static Future<void> selectionLight() => trigger(HapticType.selectionLight);
  static Future<void> successMedium() => trigger(HapticType.successMedium);
  static Future<void> warningHeavy() => trigger(HapticType.warningHeavy);
  static Future<void> errorRigid() => trigger(HapticType.errorRigid);
  static Future<void> zoomBound() => trigger(HapticType.zoomBound);
  static Future<void> longPressStart() => trigger(HapticType.longPressStart);
}
