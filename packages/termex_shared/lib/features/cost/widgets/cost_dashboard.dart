/// Spending dashboard — header (period total / task count / token
/// breakdown), by-server stacked list, top-N task rows, by-kind
/// horizontal bars.
///
/// Stateless: takes a pre-aggregated CostSummaryVM and renders. The
/// parent screen owns provider wiring + the period dropdown.
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../widgets/clickable.dart';
import '../model/cost_view_model.dart';

class CostDashboard extends StatelessWidget {
  final CostSummaryVM summary;
  /// Optional cap shown alongside the period total so users see
  /// remaining budget at a glance.
  final UserCostCapVM? caps;
  /// Called when the user taps a task row.
  final void Function(String taskId)? onTaskTap;

  const CostDashboard({
    super.key,
    required this.summary,
    this.caps,
    this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        vertical: TermexSpacing.md,
        horizontal: TermexSpacing.sm,
      ),
      children: [
        _Header(summary: summary, caps: caps),
        const SizedBox(height: TermexSpacing.lg),
        const _SectionTitle('By server'),
        const SizedBox(height: TermexSpacing.sm),
        if (summary.byServer.isEmpty)
          const _EmptyHint(label: 'No spend in this period.')
        else
          ...summary.byServer.map((s) => _ServerRow(row: s, total: summary.totalUsd)),
        const SizedBox(height: TermexSpacing.lg),
        const _SectionTitle('Top tasks'),
        const SizedBox(height: TermexSpacing.sm),
        if (summary.topTasks.isEmpty)
          const _EmptyHint(label: 'No tasks recorded.')
        else
          ...summary.topTasks.map((t) => _TaskRow(row: t, onTap: onTaskTap)),
        const SizedBox(height: TermexSpacing.lg),
        const _SectionTitle('By kind'),
        const SizedBox(height: TermexSpacing.sm),
        if (summary.byKind.isEmpty)
          const _EmptyHint(label: 'No breakdown yet.')
        else
          _KindBreakdown(byKind: summary.byKind, total: summary.totalUsd),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final CostSummaryVM summary;
  final UserCostCapVM? caps;
  const _Header({required this.summary, required this.caps});

  @override
  Widget build(BuildContext context) {
    final monthly = caps?.monthlyUsd;
    final remaining = monthly == null ? null : monthly - summary.totalUsd;
    return Container(
      padding: const EdgeInsets.all(TermexSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.periodLabel,
            style: TermexTypography.caption.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: TermexSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatUsd(summary.totalUsd),
                style: TermexTypography.heading1.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
              if (remaining != null) ...[
                const SizedBox(width: TermexSpacing.sm),
                Text(
                  '${formatUsd(remaining)} left',
                  style: TermexTypography.caption.copyWith(
                    color: remaining < 0
                        ? context.colors.danger
                        : context.colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: TermexSpacing.xs),
          Text(
            '${summary.taskCount} task${summary.taskCount == 1 ? "" : "s"} · '
            '${formatTokens(summary.totalInputTokens)} in · '
            '${formatTokens(summary.totalOutputTokens)} out',
            style: TermexTypography.caption.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: TermexSpacing.xs),
        child: Text(
          text,
          style: TermexTypography.heading4.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  final String label;
  const _EmptyHint({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.sm,
          vertical: TermexSpacing.md,
        ),
        child: Text(
          label,
          style: TermexTypography.caption.copyWith(color: context.colors.textMuted),
        ),
      );
}

class _ServerRow extends StatelessWidget {
  final ServerCostVM row;
  final double total;
  const _ServerRow({required this.row, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total <= 0 ? 0.0 : row.costUsd / total;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: TermexSpacing.xs,
        horizontal: TermexSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.serverName,
                  style: TermexTypography.body.copyWith(
                    color: context.colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${formatUsd(row.costUsd)} · ${row.taskCount} task${row.taskCount == 1 ? "" : "s"}',
                style: TermexTypography.caption.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _BarMeter(value: pct, color: context.colors.primary),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final TaskCostVM row;
  final void Function(String)? onTap;
  const _TaskRow({required this.row, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onTap == null ? null : () => onTap!(row.taskId),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.sm,
          vertical: TermexSpacing.sm,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: context.colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                row.promptPreview.isEmpty ? row.taskId : row.promptPreview,
                style: TermexTypography.body.copyWith(
                  color: context.colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: TermexSpacing.sm),
            Text(
              formatUsd(row.costUsd),
              style: TermexTypography.caption.copyWith(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindBreakdown extends StatelessWidget {
  final Map<CostKindVM, double> byKind;
  final double total;
  const _KindBreakdown({required this.byKind, required this.total});

  @override
  Widget build(BuildContext context) {
    final entries = byKind.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: TermexSpacing.xs,
              horizontal: TermexSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key.displayName,
                        style: TermexTypography.body.copyWith(
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      formatUsd(e.value),
                      style: TermexTypography.caption.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _BarMeter(
                  value: total <= 0 ? 0 : e.value / total,
                  color: _colorFor(e.key, context.colors),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _colorFor(CostKindVM kind, TermexColorScheme colors) =>
      switch (kind) {
        CostKindVM.primaryAiCall => colors.primary,
        CostKindVM.streamingSummary => colors.warning,
        CostKindVM.toolUse => colors.success,
      };
}

class _BarMeter extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  const _BarMeter({required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.backgroundTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: c.maxWidth * clamped,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
