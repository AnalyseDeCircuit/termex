/// Single task card — shown in the dashboard list and any per-server
/// task overview surface.
///
/// Layout (compact / mobile-first):
///
/// ```text
/// ┌─ prompt-first-line ──────────── status ─┐
/// │ home-dev · Claude Code · 2m 14s         │
/// │ 3 artifacts · 8.4K tokens (~$0.12)      │
/// │ output-tail-preview-truncated...        │
/// │                       [Cancel] [Detail ›] │
/// └─────────────────────────────────────────┘
/// ```
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../model/task_view_model.dart';
import 'task_status_badge.dart';

class TaskCard extends StatelessWidget {
  final TaskViewModel task;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: TermexSpacing.xs,
          horizontal: TermexSpacing.sm,
        ),
        padding: const EdgeInsets.all(TermexSpacing.md),
        decoration: BoxDecoration(
          color: TermexColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TermexColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _firstLine(task.prompt),
                    style: TermexTypography.body.copyWith(
                      color: TermexColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: TermexSpacing.sm),
                TaskStatusBadge(status: task.status),
              ],
            ),
            const SizedBox(height: TermexSpacing.xs),
            Text(
              '${task.serverName} · ${task.aiCliKind.displayName} · ${task.elapsedHuman}',
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textSecondary,
              ),
            ),
            const SizedBox(height: TermexSpacing.xs),
            _MetricsLine(task: task),
            if (task.outputTail != null && task.outputTail!.isNotEmpty) ...[
              const SizedBox(height: TermexSpacing.xs),
              Text(
                _firstLine(task.outputTail!),
                style: TermexTypography.monospace.copyWith(
                  color: TermexColors.textMuted,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (onCancel != null || onTap != null) ...[
              const SizedBox(height: TermexSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onCancel != null && !task.status.isTerminal)
                    _CardButton(
                      label: 'Cancel',
                      color: TermexColors.danger,
                      onPressed: onCancel!,
                    ),
                  if (onTap != null) ...[
                    const SizedBox(width: TermexSpacing.sm),
                    _CardButton(
                      label: 'Details ›',
                      color: TermexColors.primary,
                      onPressed: onTap!,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _firstLine(String s) {
    final i = s.indexOf('\n');
    return i < 0 ? s : s.substring(0, i);
  }
}

class _MetricsLine extends StatelessWidget {
  final TaskViewModel task;
  const _MetricsLine({required this.task});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (task.artifactSummaries.isNotEmpty) {
      parts.add('${task.artifactSummaries.length} artifacts');
    }
    final tokens = task.totalInputTokens + task.totalOutputTokens;
    if (tokens > 0) {
      final cost = task.estimatedCostUsd;
      parts.add(cost == null
          ? '${_kFormat(tokens)} tokens'
          : '${_kFormat(tokens)} tokens (~\$${cost.toStringAsFixed(2)})');
    }
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      parts.join(' · '),
      style: TermexTypography.caption.copyWith(
        color: TermexColors.textSecondary,
      ),
    );
  }

  String _kFormat(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _CardButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _CardButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.md,
          vertical: TermexSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TermexTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
