/// Shared Notifications settings tab content (v0.79.55).
///
/// Promotes the threshold UI from a mobile-only page to a cross-platform
/// SettingsPage tab so PC users see the same controls as mobile. The
/// thresholds + reset are pure SharedPreferences-backed Riverpod, so the
/// tab works identically on iOS / Android / macOS / Linux / Windows.
///
/// The "Send test notification" + "Fire demo task event" buttons that
/// previously sat above the thresholds were mobile-only affordances that
/// depended on `MobileTaskNotifier` + `TaskEventBus` (live only inside
/// the mobile shell). They surface here through an optional [header]
/// slot — the mobile shell passes a widget that renders those buttons;
/// desktop leaves the slot null and only the thresholds render.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/clickable.dart';
import '../../widgets/slider.dart';
import '../../widgets/toggle.dart';
import 'notification_settings_provider.dart';

class NotificationsTab extends StatelessWidget {
  /// Optional caller-supplied widget rendered above the thresholds
  /// section. Mobile shell uses this to surface its
  /// [MobileTaskNotifier]-backed test buttons; desktop leaves it null.
  final Widget? header;

  const NotificationsTab({super.key, this.header});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TermexColors.backgroundPrimary,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (header != null) header!,
          const _NotificationThresholdsSection(),
        ],
      ),
    );
  }
}

/// User-tunable thresholds for OS notifications (v0.79.31). Renders three
/// sliders plus a reset button. Live updates the singleton via the
/// Riverpod provider — no save action; changes persist on every move.
class _NotificationThresholdsSection extends ConsumerWidget {
  const _NotificationThresholdsSection();

  static const _sizeMaxMb = 100.0; // 0..100 MB
  static const _durationMaxSeconds = 60; // 0..60 s

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final thresholds = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    final sizeMb = thresholds.sizeBytes / (1024 * 1024);
    final durationSeconds = (thresholds.durationMs / 1000).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.notificationThresholdsTitle,
            style: TermexTypography.body.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: TermexSpacing.sm),
          TermexToggle(
            value: thresholds.sftpSuccessEnabled,
            onChanged: notifier.setSftpSuccessEnabled,
            label: l10n.notificationThresholdsSftpToggleLabel,
          ),
          const SizedBox(height: TermexSpacing.xs),
          Text(
            l10n.notificationThresholdsSftpToggleHint,
            style: TermexTypography.caption.copyWith(
              color: TermexColors.textMuted,
            ),
          ),
          const SizedBox(height: TermexSpacing.md),
          _LabeledSliderRow(
            label: l10n.notificationThresholdsSizeLabel,
            value: l10n.notificationThresholdsSizeValue(sizeMb),
            slider: TermexSlider(
              value: sizeMb.clamp(0.0, _sizeMaxMb),
              min: 0.0,
              max: _sizeMaxMb,
              divisions: 100,
              disabled: !thresholds.sftpSuccessEnabled,
              onChanged: (v) =>
                  notifier.setSizeBytes((v * 1024 * 1024).round()),
            ),
          ),
          const SizedBox(height: TermexSpacing.md),
          _LabeledSliderRow(
            label: l10n.notificationThresholdsDurationLabel,
            value: l10n.notificationThresholdsDurationValue(durationSeconds),
            slider: TermexSlider(
              value: durationSeconds.toDouble().clamp(
                    0.0,
                    _durationMaxSeconds.toDouble(),
                  ),
              min: 0.0,
              max: _durationMaxSeconds.toDouble(),
              divisions: _durationMaxSeconds,
              disabled: !thresholds.sftpSuccessEnabled,
              onChanged: (v) => notifier.setDurationMs((v * 1000).round()),
            ),
          ),
          const SizedBox(height: TermexSpacing.md),
          _LabeledSliderRow(
            label: l10n.notificationThresholdsUndoWindowLabel,
            value: thresholds.undoWindowSeconds == 0
                ? l10n.notificationThresholdsUndoWindowOff
                : l10n.notificationThresholdsUndoWindowValue(
                    thresholds.undoWindowSeconds,
                  ),
            slider: TermexSlider(
              value: thresholds.undoWindowSeconds.toDouble().clamp(0.0, 30.0),
              min: 0.0,
              max: 30.0,
              divisions: 30,
              onChanged: (v) => notifier.setUndoWindowSeconds(v.round()),
            ),
          ),
          const SizedBox(height: TermexSpacing.sm),
          Text(
            l10n.notificationThresholdsHelp,
            style: TermexTypography.caption.copyWith(
              color: TermexColors.textMuted,
            ),
          ),
          const SizedBox(height: TermexSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: Clickable(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                notifier.resetToDefaults();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  l10n.notificationThresholdsReset,
                  style: TermexTypography.body.copyWith(
                    color: TermexColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledSliderRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget slider;
  const _LabeledSliderRow({
    required this.label,
    required this.value,
    required this.slider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TermexTypography.bodySmall.copyWith(
                  color: TermexColors.textSecondary,
                ),
              ),
            ),
            Text(
              value,
              style: TermexTypography.bodySmall.copyWith(
                color: TermexColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: TermexSpacing.xs),
        slider,
      ],
    );
  }
}
