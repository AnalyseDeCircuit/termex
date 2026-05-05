import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

abstract final class AppAnimations {
  static const Duration dialogOpen = Duration(milliseconds: 220);
  static const Duration dialogClose = Duration(milliseconds: 160);
  static const Duration dialogOverlay = Duration(milliseconds: 150);

  static const Duration toastEnter = Duration(milliseconds: 200);
  static const Duration toastExit = Duration(milliseconds: 150);

  static const Duration popoverEnter = Duration(milliseconds: 120);
  static const Duration popoverExit = Duration(milliseconds: 80);

  static const Duration pageEnter = Duration(milliseconds: 250);
  static const Duration pageExit = Duration(milliseconds: 200);

  static const Duration listItemEnter = Duration(milliseconds: 150);

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve easeOutQuart = Cubic(0.25, 1.0, 0.5, 1.0);
  static const Curve easeInQuart = Cubic(0.5, 0.0, 0.75, 0.0);
  static const Curve easeOutCubic = Cubic(0.33, 1.0, 0.68, 1.0);
  static const Curve easeInOutCubic = Cubic(0.65, 0.0, 0.35, 1.0);

  static const Curve dialogOpenCurve = easeOutQuart;
  static const Curve dialogCloseCurve = easeInQuart;
  static const Curve popoverEnterCurve = easeOutCubic;
  static const Curve pageCurve = easeInOutCubic;

  static const Curve standardEasing = Cubic(0.2, 0, 0, 1);
  static const Curve exitEasing = Cubic(0.4, 0, 1, 1);
}
