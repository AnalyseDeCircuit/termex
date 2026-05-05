import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

class TermexCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool bordered;
  final List<BoxShadow>? elevation;
  final EdgeInsets? padding;
  final Color? backgroundColor;

  const TermexCard({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.bordered = true,
    this.elevation,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? TermexColors.backgroundSecondary;
    final shadow = elevation ?? TermexElevation.e0;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: TermexRadius.lg,
        border: bordered
            ? Border.all(color: TermexColors.border, width: 1)
            : null,
        boxShadow: shadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) _CardHeader(title: title!, actions: actions),
          Flexible(
            fit: FlexFit.loose,
            child: Padding(
              padding: padding ??
                  const EdgeInsets.all(TermexSpacing.md),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const _CardHeader({required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.md,
        vertical: TermexSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TermexColors.border, width: 1),
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(10),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TermexTypography.body.copyWith(
                color: TermexColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actions != null) ...[
            ...actions!.map((a) => Padding(
                  padding: const EdgeInsets.only(left: TermexSpacing.sm),
                  child: a,
                )),
          ],
        ],
      ),
    );
  }
}
