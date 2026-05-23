import 'package:flutter/painting.dart';

abstract final class MobileTokens {
  // Touch / layout
  static const double minTouchTarget = 44.0;
  static const double bottomBarHeight = 49.0;
  static const double navBarHeight = 44.0;
  static const double safeAreaInset = 34.0;
  static const double dragHandleWidth = 36.0;
  static const double dragHandleHeight = 4.0;

  // Bottom sheet snap fractions
  static const double bottomSheetSnapHalf = 0.30;
  static const double bottomSheetSnapMid = 0.60;
  static const double bottomSheetSnapFull = 0.95;

  // ===== iOS HIG font scale (Caption2 → Title1) =====
  static const double fontSize11 = 11.0; // Caption2
  static const double fontSize13 = 13.0; // Caption1 / Footnote
  static const double fontSize15 = 15.0; // Body
  static const double fontSize17 = 17.0; // Body Large / Default
  static const double fontSize22 = 22.0; // Title3
  static const double fontSize28 = 28.0; // Title1

  // ===== Font weights =====
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemibold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;

  // ===== Mobile elevation (Box shadows) =====
  static const List<BoxShadow> elevationLow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> elevationMedium = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> elevationHigh = [
    BoxShadow(color: Color(0x29000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  // ===== Animation =====
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);
}
