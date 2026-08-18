/// Dialog that lists the user's *other* devices and lets them
/// push the current task's deep link. Pure stateless — host passes
/// the device list + a callback; the parent decides whether to
/// show a loading state, snack-bar the result, or invoke FCM
/// fallback semantics.
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../widgets/clickable.dart';
import '../model/handoff_view_model.dart';

class SendToDeviceDialog extends StatelessWidget {
  final List<DeviceVM> devices;
  /// Called with the target device id when the user taps a row.
  final void Function(DeviceVM target) onSend;
  final VoidCallback onCancel;
  /// Reference instant used by `lastSeenHuman`; tests pass a stable
  /// value, prod leaves it null to use `DateTime.now()`.
  final DateTime? now;

  const SendToDeviceDialog({
    super.key,
    required this.devices,
    required this.onSend,
    required this.onCancel,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final others = devices.where((d) => !d.isSelf).toList();
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
            'Send task to device',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: TermexSpacing.sm),
          if (others.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TermexSpacing.md),
              child: Text(
                'No other devices registered.',
                style: TermexTypography.body.copyWith(
                  color: TermexColors.textSecondary,
                ),
              ),
            )
          else
            ...others.map((d) => _DeviceRow(
                  device: d,
                  onTap: () => onSend(d),
                  now: now,
                )),
          const SizedBox(height: TermexSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Clickable(
                onTap: onCancel,
                child: Text(
                  'Cancel',
                  style: TermexTypography.body.copyWith(
                    color: TermexColors.textSecondary,
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

class _DeviceRow extends StatelessWidget {
  final DeviceVM device;
  final VoidCallback onTap;
  final DateTime? now;
  const _DeviceRow({required this.device, required this.onTap, this.now});

  @override
  Widget build(BuildContext context) {
    final color = device.isOnline
        ? TermexColors.success
        : TermexColors.textMuted;
    return Clickable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.sm,
          vertical: TermexSpacing.sm,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: TermexColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: TermexSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: TermexTypography.body.copyWith(
                      color: TermexColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    device.isOnline
                        ? '${device.platform.displayName} · online'
                        : '${device.platform.displayName} · '
                            '${device.lastSeenHuman(now: now)}',
                    style: TermexTypography.caption.copyWith(
                      color: TermexColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
