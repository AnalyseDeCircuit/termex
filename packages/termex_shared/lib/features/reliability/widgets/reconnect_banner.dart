/// Top-of-screen banner that surfaces ongoing reconnect attempts.
/// Renders nothing when every connection is healthy.
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../model/task_metrics_vm.dart';

class ReconnectBanner extends StatelessWidget {
  /// Per-server attempt state. Connected entries are filtered out
  /// internally so callers can pass the full list.
  final List<ReconnectAttemptVM> attempts;
  /// Called when the user taps "Retry now" on a failed entry.
  final void Function(String serverId)? onRetry;

  const ReconnectBanner({
    super.key,
    required this.attempts,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final visible = attempts
        .where((a) => a.status != ReconnectStatusVM.connected)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final anyFailed =
        visible.any((a) => a.status == ReconnectStatusVM.failed);
    final color = anyFailed ? TermexColors.danger : TermexColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.md,
        vertical: TermexSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: visible
            .map((a) => _AttemptRow(
                  attempt: a,
                  color: _statusColor(a.status),
                  onRetry: onRetry,
                ))
            .toList(),
      ),
    );
  }

  Color _statusColor(ReconnectStatusVM s) => switch (s) {
        ReconnectStatusVM.connected => TermexColors.success,
        ReconnectStatusVM.reconnecting => TermexColors.warning,
        ReconnectStatusVM.failed => TermexColors.danger,
      };
}

class _AttemptRow extends StatelessWidget {
  final ReconnectAttemptVM attempt;
  final Color color;
  final void Function(String serverId)? onRetry;
  const _AttemptRow({
    required this.attempt,
    required this.color,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isFailed = attempt.status == ReconnectStatusVM.failed;
    final label = switch (attempt.status) {
      ReconnectStatusVM.reconnecting =>
        'Reconnecting to ${attempt.serverLabel}…',
      ReconnectStatusVM.failed => 'Lost connection to ${attempt.serverLabel}',
      ReconnectStatusVM.connected => '',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: TermexSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TermexTypography.body.copyWith(
                    color: TermexColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (attempt.note != null && attempt.note!.isNotEmpty)
                  Text(
                    attempt.note!,
                    style: TermexTypography.caption.copyWith(
                      color: TermexColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (isFailed && onRetry != null) ...[
            const SizedBox(width: TermexSpacing.sm),
            GestureDetector(
              onTap: () => onRetry!(attempt.serverId),
              child: Text(
                'Retry now',
                style: TermexTypography.body.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
