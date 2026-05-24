/// Small pill embedded in the task-detail header showing how many
/// other devices are watching the same task. Tapping opens the
/// `SendToDeviceDialog`.
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../model/handoff_view_model.dart';

class WatcherBadge extends StatelessWidget {
  /// All watchers, including the current device (with `isSelf=true`).
  final List<DeviceVM> watchers;
  /// Called when the user taps the badge — typically opens the
  /// SendToDeviceDialog.
  final VoidCallback? onTap;

  const WatcherBadge({
    super.key,
    required this.watchers,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final others = watchers.where((d) => !d.isSelf).length;
    if (others == 0) {
      // No other devices watching — render a neutral indicator
      // (still tap-able so the user can discover "Send to device").
      return _Pill(
        label: 'Only this device',
        color: TermexColors.textMuted,
        onTap: onTap,
      );
    }
    return _Pill(
      label: others == 1
          ? '1 other watching'
          : '$others others watching',
      color: TermexColors.primary,
      onTap: onTap,
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _Pill({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
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
