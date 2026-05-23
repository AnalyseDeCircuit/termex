import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../design/radius.dart';
import '../../../icons/termex_icons.dart';

/// Generic right-click menu used by [ServerTree] for both server rows,
/// group headers and the empty-area root context.
///
/// Rendered as a transient [OverlayEntry] anchored to a global click position,
/// matching `src/components/sidebar/ContextMenu.vue` from the Tauri build.
class ServerTreeContextMenu extends StatefulWidget {
  final Offset position;
  final Size screenSize;
  final List<ServerTreeMenuItem> items;
  final VoidCallback onDismiss;

  const ServerTreeContextMenu({
    super.key,
    required this.position,
    required this.screenSize,
    required this.items,
    required this.onDismiss,
  });

  @override
  State<ServerTreeContextMenu> createState() => _ServerTreeContextMenuState();
}

class _ServerTreeContextMenuState extends State<ServerTreeContextMenu>
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
    const menuWidth = 180.0;
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
                color: TermexColors.backgroundPrimary,
                borderRadius: TermexRadius.md,
                border: Border.all(color: TermexColors.border),
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
                children: widget.items
                    .map((it) => it.divided
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: TermexSpacing.xs),
                                child: ColoredBox(
                                  color: TermexColors.border,
                                  child: SizedBox(
                                      height: 1, width: double.infinity),
                                ),
                              ),
                              _ContextRow(
                                item: it,
                                onTap: () {
                                  widget.onDismiss();
                                  it.onSelect?.call();
                                },
                              ),
                            ],
                          )
                        : _ContextRow(
                            item: it,
                            onTap: () {
                              widget.onDismiss();
                              it.onSelect?.call();
                            },
                          ))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ServerTreeMenuItem {
  final IconData icon;
  final String label;
  final bool danger;
  final bool divided;
  final VoidCallback? onSelect;

  const ServerTreeMenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
    this.divided = false,
    this.onSelect,
  });
}

class _ContextRow extends StatefulWidget {
  final ServerTreeMenuItem item;
  final VoidCallback onTap;
  const _ContextRow({required this.item, required this.onTap});

  @override
  State<_ContextRow> createState() => _ContextRowState();
}

class _ContextRowState extends State<_ContextRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.item.danger
        ? TermexColors.danger
        : TermexColors.textPrimary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.md),
          color: _hovered
              ? (widget.item.danger
                  ? TermexColors.danger.withOpacity(0.1)
                  : TermexColors.backgroundTertiary)
              : const Color(0x00000000),
          child: Row(
            children: [
              TermexIconWidget(widget.item.icon, size: 13, color: color),
              const SizedBox(width: TermexSpacing.sm),
              Text(
                widget.item.label,
                style: TermexTypography.bodySmall.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
