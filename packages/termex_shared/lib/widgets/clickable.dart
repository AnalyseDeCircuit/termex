/// Pointer-cursor-aware tap target.
///
/// A bare `GestureDetector` registers taps but never changes the mouse
/// cursor, so on desktop every custom-built control (breadcrumbs, icon
/// buttons, list rows, chips…) kept the default arrow and gave the user no
/// hint that it was interactive. `MouseRegion(cursor: click)` is the fix,
/// but repeating that pair at every call site is what let ~150 of them
/// drift. Use [Clickable] instead of a raw `GestureDetector` for anything
/// the user is meant to click.
///
/// On touch platforms the `MouseRegion` is inert, so this is safe to use
/// in shared mobile/desktop widgets.
library;

import 'package:flutter/widgets.dart';

class Clickable extends StatelessWidget {
  final Widget child;

  /// Primary activation. When null the widget renders as non-interactive:
  /// no pointer cursor, no hit-testing — matching a disabled control.
  final VoidCallback? onTap;

  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  /// Secondary (right) click, with the global position — handy for
  /// context menus that need an anchor.
  final void Function(Offset globalPosition)? onSecondaryTap;

  /// Overrides the cursor. Defaults to [SystemMouseCursors.click], or
  /// [SystemMouseCursors.basic] when [onTap] is null.
  final MouseCursor? cursor;

  /// Forwarded to the inner [GestureDetector]. Use
  /// [HitTestBehavior.opaque] to catch taps on transparent padding.
  final HitTestBehavior? behavior;

  const Clickable({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.cursor,
    this.behavior,
  });

  bool get _interactive =>
      onTap != null ||
      onDoubleTap != null ||
      onLongPress != null ||
      onSecondaryTap != null;

  @override
  Widget build(BuildContext context) {
    final gesture = GestureDetector(
      behavior: behavior,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onSecondaryTapUp: onSecondaryTap == null
          ? null
          : (d) => onSecondaryTap!(d.globalPosition),
      child: child,
    );
    if (!_interactive && cursor == null) return gesture;
    return MouseRegion(
      cursor: cursor ??
          (_interactive
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic),
      child: gesture,
    );
  }
}
