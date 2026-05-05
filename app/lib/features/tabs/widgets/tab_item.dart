import 'package:flutter/material.dart';

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../design/radius.dart';
import '../../../design/spacing.dart';
import '../../../icons/termex_icons.dart';
import '../state/tab_controller.dart';

/// Individual tab chip in the tab bar.
class TabItem extends StatefulWidget {
  final String title;
  final TabStatus status;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final VoidCallback? onClone;

  const TabItem({
    super.key,
    required this.title,
    required this.status,
    required this.isActive,
    this.onTap,
    this.onClose,
    this.onClone,
  });

  @override
  State<TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<TabItem> {
  bool _hovered = false;

  Color _bgColor() {
    if (widget.isActive) return TermexColors.backgroundTertiary;
    if (_hovered) return TermexColors.backgroundSecondary.withOpacity(0.8);
    return const Color(0x00000000);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 36,
          constraints: const BoxConstraints(
            minWidth: 80,
            maxWidth: 200,
          ),
          decoration: BoxDecoration(
            color: _bgColor(),
            borderRadius: TermexRadius.sm,
            border: widget.isActive
                ? const Border(
                    bottom: BorderSide(
                      color: TermexColors.primary,
                      width: 2,
                    ),
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TabStatusIndicator(status: widget.status),
              const SizedBox(width: TermexSpacing.xs),
              Flexible(
                child: Text(
                  widget.title,
                  style: TermexTypography.bodySmall.copyWith(
                    color: widget.isActive
                        ? TermexColors.textPrimary
                        : TermexColors.textSecondary,
                    fontWeight:
                        widget.isActive ? FontWeight.w500 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: TermexSpacing.xs),
              _CloseButton(
                visible: _hovered || widget.isActive,
                onTap: widget.onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final overlay = Overlay.of(context);
    OverlayEntry? entry;

    entry = OverlayEntry(
      builder: (ctx) => _TabContextMenu(
        position: position,
        screenSize: MediaQuery.sizeOf(ctx),
        onClone: widget.onClone,
        onClose: widget.onClose,
        onDismiss: () {
          entry?.remove();
          entry = null;
        },
      ),
    );
    overlay.insert(entry!);
  }
}

// ---------------------------------------------------------------------------
// Status indicator
// ---------------------------------------------------------------------------

class _TabStatusIndicator extends StatefulWidget {
  final TabStatus status;
  const _TabStatusIndicator({required this.status});

  @override
  State<_TabStatusIndicator> createState() => _TabStatusIndicatorState();
}

class _TabStatusIndicatorState extends State<_TabStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _rotation = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    if (widget.status == TabStatus.connecting) {
      _ctrl.repeat();
    }
  }

  @override
  void didUpdateWidget(_TabStatusIndicator old) {
    super.didUpdateWidget(old);
    if (widget.status == TabStatus.connecting) {
      _ctrl.repeat();
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.status) {
      case TabStatus.connecting:
        return RotationTransition(
          turns: _rotation,
          child: SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(TermexColors.primary),
            ),
          ),
        );
      case TabStatus.connected:
        return _Dot(color: TermexColors.success);
      case TabStatus.error:
        return _Dot(color: TermexColors.danger);
      case TabStatus.disconnected:
        return _Dot(color: TermexColors.neutral);
    }
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        borderRadius: TermexRadius.full,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Close button
// ---------------------------------------------------------------------------

class _CloseButton extends StatefulWidget {
  final bool visible;
  final VoidCallback? onTap;
  const _CloseButton({required this.visible, this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 100),
      opacity: widget.visible ? 1.0 : 0.0,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _hovered
                  ? TermexColors.textMuted.withOpacity(0.3)
                  : const Color(0x00000000),
              borderRadius: TermexRadius.full,
            ),
            alignment: Alignment.center,
            child: TermexIconWidget(
              TermexIcons.close,
              size: 10,
              color: _hovered
                  ? TermexColors.textPrimary
                  : TermexColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Context menu for right-click
// ---------------------------------------------------------------------------

class _TabContextMenu extends StatefulWidget {
  final Offset position;
  final Size screenSize;
  final VoidCallback? onClone;
  final VoidCallback? onClose;
  final VoidCallback onDismiss;

  const _TabContextMenu({
    required this.position,
    required this.screenSize,
    this.onClone,
    this.onClose,
    required this.onDismiss,
  });

  @override
  State<_TabContextMenu> createState() => _TabContextMenuState();
}

class _TabContextMenuState extends State<_TabContextMenu>
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
    const menuWidth = 160.0;
    final dx = widget.position.dx + menuWidth > widget.screenSize.width
        ? widget.position.dx - menuWidth
        : widget.position.dx;

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
          top: widget.position.dy,
          child: FadeTransition(
            opacity: _fade,
            child: Container(
              width: menuWidth,
              decoration: BoxDecoration(
                color: TermexColors.backgroundSecondary,
                borderRadius: TermexRadius.md,
                border: Border.all(color: TermexColors.border),
              ),
              padding: const EdgeInsets.symmetric(vertical: TermexSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ContextItem(
                    icon: TermexIcons.copy,
                    label: 'Clone Tab',
                    onTap: () {
                      widget.onDismiss();
                      widget.onClone?.call();
                    },
                  ),
                  _ContextItem(
                    icon: TermexIcons.close,
                    label: 'Close Tab',
                    danger: true,
                    onTap: () {
                      widget.onDismiss();
                      widget.onClose?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContextItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback? onTap;
  const _ContextItem({
    required this.icon,
    required this.label,
    this.danger = false,
    this.onTap,
  });

  @override
  State<_ContextItem> createState() => _ContextItemState();
}

class _ContextItemState extends State<_ContextItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.danger ? TermexColors.danger : TermexColors.textPrimary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.md),
          color: _hovered
              ? (widget.danger
                  ? TermexColors.danger.withOpacity(0.1)
                  : TermexColors.backgroundTertiary)
              : const Color(0x00000000),
          child: Row(
            children: [
              TermexIconWidget(widget.icon, size: 13, color: color),
              const SizedBox(width: TermexSpacing.sm),
              Text(
                widget.label,
                style: TermexTypography.bodySmall.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
