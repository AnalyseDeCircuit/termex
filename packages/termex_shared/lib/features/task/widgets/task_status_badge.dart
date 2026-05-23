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
    final (color, label) = _styling(status);
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

  (Color, String) _styling(TaskStatus s) {
    switch (s) {
      case TaskStatus.pending:
        return (TermexColors.textMuted, 'Pending');
      case TaskStatus.pendingConfirmation:
        return (TermexColors.warning, 'Awaiting confirm');
      case TaskStatus.running:
        return (TermexColors.primary, 'Running');
      case TaskStatus.succeeded:
        return (TermexColors.success, 'Succeeded');
      case TaskStatus.failed:
        return (TermexColors.danger, 'Failed');
      case TaskStatus.cancelled:
        return (TermexColors.textMuted, 'Cancelled');
    }
  }
}
