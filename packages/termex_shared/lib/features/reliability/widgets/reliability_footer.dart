/// Dev-mode footer that surfaces per-task reliability counters.
/// Renders nothing when `visible` is false so the prod build pays
/// only a const-widget cost.
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../model/task_metrics_vm.dart';

class ReliabilityFooter extends StatelessWidget {
  final TaskMetricsVM? metrics;
  /// Gate to keep this widget off the prod build by default. The
  /// host passes a settings flag or `kDebugMode`.
  final bool visible;

  const ReliabilityFooter({
    super.key,
    required this.metrics,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final m = metrics;
    if (m == null) {
      return _row(context, 'No metrics recorded yet.');
    }
    final pushLabel =
        m.pushLatencyMs == null ? '—' : '${m.pushLatencyMs}ms';
    return _row(
      context,
      'WS ${formatDurationMs(m.wsUptimeMs)} · '
      'Reconnects ${m.reconnectCount} · '
      'BG ${formatDurationMs(m.bgDurationMs)} · '
      'Push $pushLabel · '
      'Handoffs ${m.handoffCount}',
    );
  }

  Widget _row(BuildContext context, String label) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.md,
          vertical: TermexSpacing.xs,
        ),
        color: context.colors.backgroundSecondary,
        child: Text(
          label,
          style: TermexTypography.caption.copyWith(
            color: context.colors.textMuted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
}
