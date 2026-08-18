/// Renders a [Playbook] as a card with per-step run buttons.
library;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/radius.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../widgets/clickable.dart';
import '../features/playbook.dart';

/// Callback fired when the user requests to run a single step.
typedef RunStepCallback = void Function(PlaybookStep step);

class CommandSequenceCard extends StatelessWidget {
  final Playbook playbook;
  final RunStepCallback onRunStep;
  final VoidCallback onRunAll;

  const CommandSequenceCard({
    super.key,
    required this.playbook,
    required this.onRunStep,
    required this.onRunAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: TermexSpacing.sm),
      padding: const EdgeInsets.all(TermexSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        borderRadius: TermexRadius.md,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(title: playbook.title, onRunAll: onRunAll),
          const SizedBox(height: TermexSpacing.sm),
          for (var i = 0; i < playbook.steps.length; i++)
            _StepRow(
              step: playbook.steps[i],
              index: i + 1,
              total: playbook.steps.length,
              canRun: playbook.canRun(playbook.steps[i].id),
              onRun: () => onRunStep(playbook.steps[i]),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onRunAll;
  const _Header({required this.title, required this.onRunAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.playlist_play, size: 16, color: context.colors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: TermexTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        Clickable(
          onTap: onRunAll,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TermexSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: context.colors.primary,
              borderRadius: TermexRadius.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow, size: 12, color: Color(0xFFFFFFFF)),
                const SizedBox(width: 2),
                Text(
                  '全部运行',
                  style: TermexTypography.caption.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final PlaybookStep step;
  final int index;
  final int total;
  final bool canRun;
  final VoidCallback onRun;

  const _StepRow({
    required this.step,
    required this.index,
    required this.total,
    required this.canRun,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.colors.backgroundPrimary,
        borderRadius: TermexRadius.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusDot(status: step.status),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$index/$total',
                      style: TermexTypography.caption.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        step.title,
                        style: TermexTypography.bodySmall.copyWith(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _RiskBadge(risk: step.risk),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  step.command,
                  style: TermexTypography.caption.copyWith(
                    color: context.colors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Clickable(
            onTap: canRun && step.status != PlaybookStepStatus.running
                ? onRun
                : null,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: canRun
                    ? context.colors.primary.withValues(alpha: 0.1)
                    : context.colors.backgroundTertiary,
                borderRadius: TermexRadius.sm,
              ),
              child: Icon(
                Icons.play_arrow,
                size: 14,
                color: canRun
                    ? context.colors.primary
                    : context.colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final PlaybookStepStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PlaybookStepStatus.pending => context.colors.textMuted,
      PlaybookStepStatus.running => context.colors.warning,
      PlaybookStepStatus.success => context.colors.success,
      PlaybookStepStatus.failed => context.colors.danger,
      PlaybookStepStatus.skipped => context.colors.textSecondary,
    };
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final PlaybookRisk risk;
  const _RiskBadge({required this.risk});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (risk) {
      PlaybookRisk.low => ('低', context.colors.success),
      PlaybookRisk.medium => ('中', context.colors.warning),
      PlaybookRisk.high => ('高', context.colors.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TermexTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
