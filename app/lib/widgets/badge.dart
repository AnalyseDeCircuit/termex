import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

enum BadgeVariant { count, dot, status }

enum StatusColor { success, warning, danger, neutral }

class TermexBadge extends StatelessWidget {
  final Widget child;
  final int? count;
  final bool dot;
  final BadgeVariant variant;
  final int maxCount;

  const TermexBadge({
    super.key,
    required this.child,
    this.count,
    this.dot = false,
    this.variant = BadgeVariant.count,
    this.maxCount = 99,
  });

  String _countLabel() {
    if (count == null) return '';
    if (count! > maxCount) return '$maxCount+';
    return '$count';
  }

  Color get _badgeColor => TermexColors.danger;

  @override
  Widget build(BuildContext context) {
    Widget? badge;

    if (variant == BadgeVariant.dot || dot) {
      badge = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: _badgeColor,
          shape: BoxShape.circle,
        ),
      );
    } else if (variant == BadgeVariant.count && count != null && count! > 0) {
      final label = _countLabel();
      badge = Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: _badgeColor,
          borderRadius: TermexRadius.full,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TermexTypography.caption.copyWith(
            color: const Color(0xFFFFFFFF),
          ),
        ),
      );
    }

    if (badge == null) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -4,
          child: badge,
        ),
      ],
    );
  }
}
