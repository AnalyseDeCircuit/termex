import 'package:flutter/painting.dart';

abstract final class TermexRadius {
  static const BorderRadius none = BorderRadius.zero;

  static const BorderRadius sm = BorderRadius.all(Radius.circular(4));

  static const BorderRadius md = BorderRadius.all(Radius.circular(6));

  static const BorderRadius lg = BorderRadius.all(Radius.circular(10));

  static const BorderRadius full = BorderRadius.all(Radius.circular(9999));
}
