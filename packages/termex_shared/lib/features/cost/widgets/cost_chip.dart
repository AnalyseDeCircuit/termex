/// Compact cost indicator embedded in TaskCard / task headers.
///
/// Layout: `$0.12 · 8.4K tok` — color-coded against the optional
/// cap so users see at a glance whether a task is trending hot.
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../model/cost_view_model.dart';

class CostChip extends StatelessWidget {
  final double costUsd;
  final int totalTokens;
  /// Optional single-task cap so the chip can switch to warning
  /// / danger colors as the task approaches it. `null` = unlimited.
  final double? singleTaskCapUsd;

  const CostChip({
    super.key,
    required this.costUsd,
    required this.totalTokens,
    this.singleTaskCapUsd,
  });

  @override
  Widget build(BuildContext context) {
    final color = _chipColor(context.colors);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        '${formatUsd(costUsd)} · ${formatTokens(totalTokens)} tok',
        style: TermexTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _chipColor(TermexColorScheme colors) {
    final cap = singleTaskCapUsd;
    if (cap == null || cap <= 0) return colors.textSecondary;
    final ratio = costUsd / cap;
    if (ratio >= 1.0) return colors.danger;
    if (ratio >= 0.75) return colors.warning;
    return colors.textSecondary;
  }
}
