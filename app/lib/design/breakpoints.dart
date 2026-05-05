import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

abstract final class Breakpoints {
  static const double sidebar = 900.0;
  static const double compact = 600.0;
}

@immutable
class BreakpointState {
  final bool sidebarExpanded;
  final bool compact;

  const BreakpointState({
    required this.sidebarExpanded,
    required this.compact,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BreakpointState &&
          sidebarExpanded == other.sidebarExpanded &&
          compact == other.compact;

  @override
  int get hashCode => Object.hash(sidebarExpanded, compact);
}
