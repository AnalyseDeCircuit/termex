/// Confirmation dialog asking the user "really take over from {name}?"
/// before sending `handoff.takeover` to the daemon.
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';

class TakeoverConfirmDialog extends StatelessWidget {
  final String currentOwnerName;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const TakeoverConfirmDialog({
    super.key,
    required this.currentOwnerName,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TermexSpacing.lg),
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: TermexColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TermexColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Take over task?',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: TermexSpacing.sm),
          Text(
            '$currentOwnerName is the current owner. After taking '
            'over, you will receive notifications and approval prompts '
            'for this task.',
            style: TermexTypography.body.copyWith(
              color: TermexColors.textSecondary,
            ),
          ),
          const SizedBox(height: TermexSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TermexSpacing.md,
                    vertical: TermexSpacing.sm,
                  ),
                  child: Text(
                    'Cancel',
                    style: TermexTypography.body.copyWith(
                      color: TermexColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TermexSpacing.sm),
              GestureDetector(
                onTap: onConfirm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TermexSpacing.lg,
                    vertical: TermexSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: TermexColors.primary.withValues(alpha: 0.18),
                    border: Border.all(
                      color: TermexColors.primary.withValues(alpha: 0.6),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Take over',
                    style: TermexTypography.body.copyWith(
                      color: TermexColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
