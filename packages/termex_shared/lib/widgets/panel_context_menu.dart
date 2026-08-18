/// Shared helpers for sidebar panel context menus.
///
/// Every sidebar tab offers two right-click menus:
///
///  * **blank area** — create / import / refresh, i.e. what applies to the
///    panel as a whole. Wire it on a `GestureDetector` with
///    `behavior: HitTestBehavior.opaque` wrapping the panel body, so empty
///    space below the last row still responds.
///  * **on a row** — what applies to that one entry. Wire it on the row and
///    let it win: an inner detector consumes the gesture, so the panel-level
///    menu does not also fire.
///
/// Only the servers tab had either of these; the other four had none.
library;

import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../icons/termex_icons.dart';
import 'menu.dart';

/// A leading icon sized and coloured for a [MenuItem].
///
/// Every menu would otherwise repeat the same `TermexIconWidget(icon,
/// size: 13, color: …)`, and the destructive entries would drift out of sync
/// with their red label.
Widget menuIcon(BuildContext context, IconData icon, {bool danger = false}) =>
    TermexIconWidget(
      icon,
      size: 13,
      color: danger ? context.colors.danger : context.colors.textSecondary,
    );

/// Convenience for the standard destructive entry.
MenuItem deleteMenuItem(
  BuildContext context, {
  required String label,
  required VoidCallback onSelected,
}) =>
    MenuItem(
      label: label,
      danger: true,
      icon: menuIcon(context, TermexIcons.delete, danger: true),
      onSelected: onSelected,
    );
