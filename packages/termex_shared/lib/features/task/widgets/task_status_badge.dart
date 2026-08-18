/// Single-line colored status badge for a [TaskViewModel].
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../model/task_view_model.dart';

class TaskStatusBadge extends StatelessWidget {
  final TaskStatus status;
  const TaskStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = _styling(status, context.colors);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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

  (Color, String) _styling(TaskStatus s, TermexColorScheme colors) {
    switch (s) {
      case TaskStatus.pending:
        return (colors.textMuted, 'Pending');
      case TaskStatus.pendingConfirmation:
        return (colors.warning, 'Awaiting confirm');
      case TaskStatus.running:
        return (colors.primary, 'Running');
      case TaskStatus.succeeded:
        return (colors.success, 'Succeeded');
      case TaskStatus.failed:
        return (colors.danger, 'Failed');
      case TaskStatus.cancelled:
        return (colors.textMuted, 'Cancelled');
    }
  }
}
