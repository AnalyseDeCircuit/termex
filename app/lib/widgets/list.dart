import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

class TermexList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int index) itemBuilder;
  final Widget? emptyWidget;
  final bool divided;
  final bool virtualScroll;
  final EdgeInsets? padding;

  const TermexList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.emptyWidget,
    this.divided = false,
    this.virtualScroll = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyWidget != null) {
      return emptyWidget!;
    }

    if (virtualScroll) {
      return ListView.separated(
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, __) => divided
            ? Container(
                height: 1,
                color: TermexColors.border,
              )
            : const SizedBox.shrink(),
        itemBuilder: (ctx, i) => itemBuilder(ctx, items[i], i),
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      children.add(itemBuilder(context, items[i], i));
      if (divided && i < items.length - 1) {
        children.add(Container(height: 1, color: TermexColors.border));
      }
    }
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class TermexListTile extends StatefulWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool disabled;

  const TermexListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.disabled = false,
  });

  @override
  State<TermexListTile> createState() => _TermexListTileState();
}

class _TermexListTileState extends State<TermexListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final double height = widget.subtitle != null ? 56.0 : 40.0;

    Color bgColor = const Color(0x00000000);
    if (widget.selected) {
      bgColor = TermexColors.backgroundTertiary;
    } else if (_hovered) {
      bgColor = TermexColors.backgroundTertiary;
    }

    Widget content = Container(
      height: height,
      color: bgColor,
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.md,
        vertical: TermexSpacing.sm,
      ),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: TermexSpacing.sm),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TermexTypography.body.copyWith(
                    color: TermexColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: TermexTypography.bodySmall.copyWith(
                      color: TermexColors.textSecondary,
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
    );

    if (widget.selected) {
      content = Stack(
        children: [
          content,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              color: TermexColors.primary,
            ),
          ),
        ],
      );
    }

    if (widget.disabled) {
      content = Opacity(opacity: 0.4, child: content);
    }

    return MouseRegion(
      onEnter: widget.disabled ? null : (_) => setState(() => _hovered = true),
      onExit: widget.disabled ? null : (_) => setState(() => _hovered = false),
      cursor: widget.disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.disabled ? null : widget.onTap,
        onLongPress: widget.disabled ? null : widget.onLongPress,
        child: content,
      ),
    );
  }
}
