import 'package:flutter/widgets.dart';
import '../design/colors.dart';
import '../design/mobile_tokens.dart';
import '../design/radius.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../system/haptic.dart';

// Mobile-optimised list item: 44pt min touch target, press-scale, haptic,
// optional swipe-to-delete (endToStart only — matches gesture matrix).
class TermexListItem extends StatefulWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  // Set to a non-null callback to enable swipe-to-dismiss (endToStart only).
  final Future<bool?> Function()? onDismiss;
  final String? dismissConfirmLabel;

  final bool selected;
  final bool disabled;

  const TermexListItem({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.onDismiss,
    this.dismissConfirmLabel,
    this.selected = false,
    this.disabled = false,
  });

  @override
  State<TermexListItem> createState() => _TermexListItemState();
}

class _TermexListItemState extends State<TermexListItem>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  bool get _isInteractive => !widget.disabled && widget.onTap != null;

  void _onTapDown(TapDownDetails _) {
    if (!_isInteractive) return;
    setState(() => _pressed = true);
    _scaleCtrl.forward();
    TermexHaptic.selectionLight();
  }

  void _onTapUp(TapUpDetails _) {
    if (!_isInteractive) return;
    setState(() => _pressed = false);
    _scaleCtrl.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    setState(() => _pressed = false);
    _scaleCtrl.reverse();
  }

  void _onLongPress() {
    if (widget.disabled) return;
    TermexHaptic.longPressStart();
    widget.onLongPress?.call();
  }

  Widget _buildContent() {
    final bg = widget.selected
        ? context.colors.primary.withAlpha(30)
        : _pressed
            ? context.colors.backgroundTertiary
            : context.colors.backgroundSecondary;

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        constraints: const BoxConstraints(minHeight: MobileTokens.minTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.lg,
          vertical: TermexSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: TermexRadius.md,
        ),
        child: Row(
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: TermexSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: TermexTypography.body.copyWith(
                      color: widget.disabled
                          ? context.colors.textMuted
                          : context.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: TermexTypography.bodySmall.copyWith(
                        color: context.colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: TermexSpacing.sm),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget item = Semantics(
      button: widget.onTap != null,
      selected: widget.selected,
      enabled: !widget.disabled,
      label: widget.title,
      hint: widget.subtitle,
      child: GestureDetector(
        onTapDown: _isInteractive ? _onTapDown : null,
        onTapUp: _isInteractive ? _onTapUp : null,
        onTapCancel: _onTapCancel,
        onLongPress: widget.onLongPress != null ? _onLongPress : null,
        child: _buildContent(),
      ),
    );

    if (widget.onDismiss != null) {
      item = Dismissible(
        key: widget.key ?? ValueKey(widget.title),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async => widget.onDismiss!(),
        background: _DismissBackground(label: widget.dismissConfirmLabel),
        child: item,
      );
    }

    return item;
  }
}

class _DismissBackground extends StatelessWidget {
  final String? label;
  const _DismissBackground({this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: TermexSpacing.lg),
      color: context.colors.danger,
      child: Text(
        label ?? '删除',
        style: TermexTypography.body.copyWith(
          color: const Color(0xFFFFFFFF),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
