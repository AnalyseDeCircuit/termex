import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../design/radius.dart';
import '../icons/termex_icons.dart';

/// Generic right-click menu, shared by the sidebar tree and the SFTP file
/// browser.
///
/// Dense by desktop convention: 32px rows against Material's 48px minimum,
/// which made the SFTP menu look padded and cramped at the same time.
///
/// Rendered as a transient [OverlayEntry] anchored to a global click position,
/// matching `src/components/sidebar/ContextMenu.vue` from the Tauri build.
class TermexContextMenu extends StatefulWidget {
  final Offset position;
  final Size screenSize;
  final List<TermexMenuItem> items;
  final VoidCallback onDismiss;

  /// Widened by callers whose labels need it — SFTP actions are longer than
  /// the sidebar's.
  final double width;

  const TermexContextMenu({
    super.key,
    required this.position,
    required this.screenSize,
    required this.items,
    required this.onDismiss,
    this.width = 180,
  });

  @override
  State<TermexContextMenu> createState() => _TermexContextMenuState();
}

class _TermexContextMenuState extends State<TermexContextMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  /// Index of the row whose flyout is currently open, if any.
  int? _openSubmenu;

  /// Anchors each submenu-bearing row so its flyout can be positioned against
  /// the row itself rather than against a height computed from item counts,
  /// which dividers and ellipsised labels would throw off.
  final Map<int, LayerLink> _links = {};

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

  LayerLink _linkFor(int index) => _links.putIfAbsent(index, LayerLink.new);

  Widget _buildRow(int index, TermexMenuItem item) {
    final row = _ContextRow(
      item: item,
      onTap: () {
        widget.onDismiss();
        item.onSelect?.call();
      },
      onHoverChanged: (hovered) {
        // Hovering any row closes a sibling's flyout; only a row that has one
        // opens it.
        setState(() {
          if (hovered) {
            _openSubmenu = item.hasChildren ? index : null;
          } else if (!item.hasChildren && _openSubmenu == index) {
            _openSubmenu = null;
          }
        });
      },
    );
    if (!item.hasChildren) return row;
    return CompositedTransformTarget(link: _linkFor(index), child: row);
  }

  @override
  Widget build(BuildContext context) {
    final menuWidth = widget.width;
    final dx = widget.position.dx + menuWidth > widget.screenSize.width
        ? widget.position.dx - menuWidth
        : widget.position.dx;
    final estimatedHeight = widget.items.length * 32.0 + 16.0;
    final dy = widget.position.dy + estimatedHeight > widget.screenSize.height
        ? widget.position.dy - estimatedHeight
        : widget.position.dy;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
            onSecondaryTap: widget.onDismiss,
          ),
        ),
        Positioned(
          left: dx,
          top: dy,
          child: FadeTransition(
            opacity: _fade,
            child: Container(
              width: menuWidth,
              padding: const EdgeInsets.symmetric(vertical: TermexSpacing.xs),
              decoration: BoxDecoration(
                color: context.colors.backgroundPrimary,
                borderRadius: TermexRadius.md,
                border: Border.all(color: context.colors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, it) in widget.items.indexed)
                    if (it.divided)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: TermexSpacing.xs),
                            child: ColoredBox(
                              color: context.colors.border,
                              child: const SizedBox(
                                  height: 1, width: double.infinity),
                            ),
                          ),
                          _buildRow(index, it),
                        ],
                      )
                    else
                      _buildRow(index, it),
                ],
              ),
            ),
          ),
        ),
        if (_openSubmenu != null) _buildSubmenu(_openSubmenu!, menuWidth),
      ],
    );
  }

  /// Flyout for the hovered parent row, anchored to its right edge.
  Widget _buildSubmenu(int index, double parentWidth) {
    final item = widget.items[index];
    const submenuWidth = 200.0;

    return CompositedTransformFollower(
      link: _linkFor(index),
      showWhenUnlinked: false,
      // Overlap the parent by a few pixels so the pointer can cross into the
      // flyout without passing over a gap, which would close it mid-travel.
      offset: Offset(parentWidth - 4, -TermexSpacing.xs),
      child: Align(
        alignment: Alignment.topLeft,
        child: MouseRegion(
          onEnter: (_) => setState(() => _openSubmenu = index),
          onExit: (_) => setState(() => _openSubmenu = null),
          child: Container(
            width: submenuWidth,
            constraints: BoxConstraints(
              maxHeight: widget.screenSize.height * 0.6,
            ),
            padding: const EdgeInsets.symmetric(vertical: TermexSpacing.xs),
            decoration: BoxDecoration(
              color: context.colors.backgroundPrimary,
              borderRadius: TermexRadius.md,
              border: Border.all(color: context.colors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final child in item.children!)
                    if (child.divided)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: TermexSpacing.xs),
                            child: ColoredBox(
                              color: context.colors.border,
                              child: const SizedBox(
                                  height: 1, width: double.infinity),
                            ),
                          ),
                          _ContextRow(
                            item: child,
                            onTap: () {
                              widget.onDismiss();
                              child.onSelect?.call();
                            },
                          ),
                        ],
                      )
                    else
                      _ContextRow(
                        item: child,
                        onTap: () {
                          widget.onDismiss();
                          child.onSelect?.call();
                        },
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TermexMenuItem {
  final IconData icon;
  final String label;
  final bool danger;
  final bool divided;
  final VoidCallback? onSelect;

  /// Nested entries, revealed on hover. Used by "Move to Group", which lists
  /// every group plus an ungroup entry — the legacy sidebar showed the same
  /// set as a flyout rather than flattening it into the parent menu.
  ///
  /// An item with children is not itself selectable; [onSelect] is ignored.
  final List<TermexMenuItem>? children;

  const TermexMenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
    this.divided = false,
    this.onSelect,
    this.children,
  });

  bool get hasChildren => children != null && children!.isNotEmpty;
}

class _ContextRow extends StatefulWidget {
  final TermexMenuItem item;
  final VoidCallback onTap;

  /// Called with the row's hover state so the parent menu can open or close
  /// this row's submenu flyout.
  final void Function(bool hovered)? onHoverChanged;

  const _ContextRow({
    required this.item,
    required this.onTap,
    this.onHoverChanged,
  });

  @override
  State<_ContextRow> createState() => _ContextRowState();
}

class _ContextRowState extends State<_ContextRow> {
  bool _hovered = false;

  void _setHovered(bool value) {
    setState(() => _hovered = value);
    widget.onHoverChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.item.danger
        ? context.colors.danger
        : context.colors.textPrimary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        // A parent row only reveals its flyout; selecting it would dismiss the
        // menu before the nested entries could be reached.
        onTap: widget.item.hasChildren ? null : widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.md),
          color: _hovered
              ? (widget.item.danger
                  ? context.colors.danger.withValues(alpha: 0.1)
                  : context.colors.backgroundTertiary)
              : const Color(0x00000000),
          child: Row(
            children: [
              TermexIconWidget(widget.item.icon, size: 13, color: color),
              const SizedBox(width: TermexSpacing.sm),
              Expanded(
                child: Text(
                  widget.item.label,
                  overflow: TextOverflow.ellipsis,
                  style: TermexTypography.bodySmall.copyWith(color: color),
                ),
              ),
              if (widget.item.hasChildren)
                TermexIconWidget(TermexIcons.chevronRight,
                    size: 12, color: context.colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
