/// Inline banner displayed in the task-detail header when another
/// device has taken ownership of this task. Offers a one-tap
/// "Take back" action so the user can reclaim without leaving the
/// detail view.
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../widgets/clickable.dart';

class TakenOverBanner extends StatelessWidget {
  final String newOwnerName;
  /// Called when the user taps "Take back". Host should chain into
  /// the takeover dialog flow.
  final VoidCallback? onTakeBack;

  const TakenOverBanner({
    super.key,
    required this.newOwnerName,
    this.onTakeBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.md,
        vertical: TermexSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.warning.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(
            color: context.colors.warning.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: context.colors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: TermexSpacing.sm),
          Expanded(
            child: Text(
              'Taken over by $newOwnerName',
              style: TermexTypography.body.copyWith(
                color: context.colors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTakeBack != null) ...[
            const SizedBox(width: TermexSpacing.sm),
            Clickable(
              onTap: onTakeBack,
              child: Text(
                'Take back',
                style: TermexTypography.body.copyWith(
                  color: context.colors.warning,
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
