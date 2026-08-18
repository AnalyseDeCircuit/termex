import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../design/radius.dart';
import '../design/spacing.dart';
import '../design/elevation.dart';

@immutable
class MenuItem {
  final String? label;
  final Widget? icon;
  final String? shortcut;
  final VoidCallback? onSelected;
  final bool isSeparator;
  final bool disabled;

  /// Renders the label in the danger colour. For destructive entries
  /// (Delete, Remove) so they read as such before being clicked — the
  /// server tree's bespoke menu already did this and the shared one must
  /// match, or the same action looks different tab to tab.
  final bool danger;

  final List<MenuItem>? subMenu;

  const MenuItem({
    this.label,
    this.icon,
    this.shortcut,
    this.onSelected,
    this.isSeparator = false,
    this.disabled = false,
    this.danger = false,
    this.subMenu,
  });

  const MenuItem.separator()
      : label = null,
        icon = null,
        shortcut = null,
        onSelected = null,
        isSeparator = true,
        disabled = false,
        danger = false,
        subMenu = null;
}

class TermexMenu extends StatelessWidget {
  final List<MenuItem> items;

  const TermexMenu({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        borderRadius: TermexRadius.md,
        border: Border.all(color: context.colors.border),
        boxShadow: TermexElevation.e2,
      ),
      padding: const EdgeInsets.symmetric(vertical: TermexSpacing.xs),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items.map((item) {
            if (item.isSeparator) return const _MenuSeparator();
            return _MenuItemTile(item: item);
          }).toList(),
        ),
      ),
    );
  }
}

class _MenuSeparator extends StatelessWidget {
  const _MenuSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: TermexSpacing.xs),
      color: context.colors.border,
    );
  }
}

class _MenuItemTile extends StatefulWidget {
  final MenuItem item;
  const _MenuItemTile({required this.item});

  @override
  State<_MenuItemTile> createState() => _MenuItemTileState();
}

class _MenuItemTileState extends State<_MenuItemTile> {
  bool _hovered = false;
  OverlayEntry? _subMenuEntry;

  @override
  void dispose() {
    _closeSubMenu();
    super.dispose();
  }

  void _closeSubMenu() {
    _subMenuEntry?.remove();
    _subMenuEntry = null;
  }

  void _openSubMenu(BuildContext context) {
    if (widget.item.subMenu == null || widget.item.subMenu!.isEmpty) return;
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _subMenuEntry = OverlayEntry(
      builder: (ctx) => _SubMenuOverlay(
        position: Offset(offset.dx + size.width, offset.dy),
        items: widget.item.subMenu!,
        onDismiss: _closeSubMenu,
      ),
    );
    Overlay.of(context).insert(_subMenuEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasSubMenu = item.subMenu != null && item.subMenu!.isNotEmpty;

    return Opacity(
      opacity: item.disabled ? 0.4 : 1.0,
      child: MouseRegion(
        cursor: item.disabled || item.onSelected == null && !hasSubMenu
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) {
          setState(() => _hovered = true);
          if (hasSubMenu) _openSubMenu(context);
        },
        onExit: (_) {
          setState(() => _hovered = false);
          if (!hasSubMenu) return;
          _closeSubMenu();
        },
        child: GestureDetector(
          onTap: item.disabled
              ? null
              : () {
                  item.onSelected?.call();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            height: 32,
            padding: const EdgeInsets.symmetric(
                horizontal: TermexSpacing.md),
            color: _hovered && !item.disabled
                ? context.colors.backgroundTertiary
                : const Color(0x00000000),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: item.icon,
                  ),
                  const SizedBox(width: TermexSpacing.sm),
                ],
                Expanded(
                  child: Text(
                    item.label ?? '',
                    style: TermexTypography.body.copyWith(
                      color: item.danger
                          ? context.colors.danger
                          : context.colors.textPrimary,
                    ),
                  ),
                ),
                if (item.shortcut != null) ...[
                  const SizedBox(width: TermexSpacing.lg),
                  Text(
                    item.shortcut!,
                    style: TermexTypography.caption.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
                if (hasSubMenu) ...[
                  const SizedBox(width: TermexSpacing.sm),
                  const _SubMenuArrow(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubMenuArrow extends StatelessWidget {
  const _SubMenuArrow();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(6, 10),
      painter: _ArrowPainter(colors: context.colors),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final TermexColorScheme colors;

  const _ArrowPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colors.textSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.colors != colors;
}

class _SubMenuOverlay extends StatelessWidget {
  final Offset position;
  final List<MenuItem> items;
  final VoidCallback onDismiss;

  const _SubMenuOverlay({
    required this.position,
    required this.items,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.translucent,
          ),
        ),
        Positioned(
          left: position.dx,
          top: position.dy,
          child: TermexMenu(items: items),
        ),
      ],
    );
  }
}

Future<void> showContextMenu({
  required BuildContext context,
  required Offset position,
  required List<MenuItem> items,
}) async {
  final overlay = Overlay.of(context);
  final size = MediaQuery.sizeOf(context);
  OverlayEntry? entry;

  void dismiss() {
    entry?.remove();
    entry = null;
  }

  entry = OverlayEntry(
    builder: (ctx) => _ContextMenuEntry(
      position: position,
      screenSize: size,
      items: _dismissOnSelect(items, dismiss),
      onDismiss: dismiss,
    ),
  );
  overlay.insert(entry!);
}

/// Rebuilds [items] so choosing one closes the menu.
///
/// `_MenuItemTile` only invoked `onSelected`; nothing tore the overlay down,
/// so the menu stayed on screen after a click and the next right-click
/// stacked another one on top. Wrapping here rather than inside the tile
/// keeps `TermexMenu` usable as an inline (non-overlay) menu, where
/// self-dismissal would be wrong.
///
/// Submenus are wrapped recursively; a parent that only opens a submenu has
/// no `onSelected` and is left alone so it does not close on hover-through.
List<MenuItem> _dismissOnSelect(List<MenuItem> items, VoidCallback dismiss) {
  return items.map((item) {
    if (item.isSeparator) return item;
    final nested = item.subMenu == null
        ? null
        : _dismissOnSelect(item.subMenu!, dismiss);
    final onSelected = item.onSelected;
    return MenuItem(
      label: item.label,
      icon: item.icon,
      shortcut: item.shortcut,
      disabled: item.disabled,
      danger: item.danger,
      subMenu: nested,
      onSelected: onSelected == null
          ? null
          : () {
              dismiss();
              onSelected();
            },
    );
  }).toList(growable: false);
}

class _ContextMenuEntry extends StatefulWidget {
  final Offset position;
  final Size screenSize;
  final List<MenuItem> items;
  final VoidCallback onDismiss;

  const _ContextMenuEntry({
    required this.position,
    required this.screenSize,
    required this.items,
    required this.onDismiss,
  });

  @override
  State<_ContextMenuEntry> createState() => _ContextMenuEntryState();
}

class _ContextMenuEntryState extends State<_ContextMenuEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const menuWidth = 200.0;
    const itemHeight = 32.0;
    const separatorHeight = 9.0;
    const verticalPadding = 8.0;

    final dx = widget.position.dx + menuWidth > widget.screenSize.width
        ? widget.position.dx - menuWidth
        : widget.position.dx;

    // Flip above the pointer when the menu would overflow the bottom edge.
    // Only dx was clamped before, so a right-click near the bottom of the
    // sidebar rendered a menu whose lower entries were unreachable — and the
    // longer per-node menus added for proxies / snippets / recordings make
    // that the common case rather than an edge case.
    final estimatedHeight = verticalPadding +
        widget.items.fold<double>(
          0,
          (h, i) => h + (i.isSeparator ? separatorHeight : itemHeight),
        );
    final overflowsBottom =
        widget.position.dy + estimatedHeight > widget.screenSize.height;
    final dy = overflowsBottom
        ? (widget.position.dy - estimatedHeight).clamp(0.0, widget.screenSize.height)
        : widget.position.dy;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
          ),
        ),
        Positioned(
          left: dx,
          top: dy,
          child: FadeTransition(
            opacity: _fade,
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  widget.onDismiss();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TermexMenu(items: widget.items),
            ),
          ),
        ),
      ],
    );
  }
}
