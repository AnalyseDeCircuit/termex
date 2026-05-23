import 'package:flutter/painting.dart';

abstract final class TermexTypography {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.2,
    decoration: TextDecoration.none,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    height: 1.25,
    decoration: TextDecoration.none,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    decoration: TextDecoration.none,
  );

  static const TextStyle heading4 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
    decoration: TextDecoration.none,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
    decoration: TextDecoration.none,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.5,
    decoration: TextDecoration.none,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    height: 1.5,
    decoration: TextDecoration.none,
  );

  static const TextStyle monospace = TextStyle(
    fontSize: 14,
    fontFamily: 'JetBrainsMono',
    fontFamilyFallback: ['Menlo', 'Consolas', 'Courier New', 'monospace'],
    height: 1.4,
    decoration: TextDecoration.none,
  );
}
