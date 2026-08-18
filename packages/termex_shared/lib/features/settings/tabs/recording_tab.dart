import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/clickable.dart';
import '../state/settings_provider.dart';

/// Terminal session recording configuration tab.
class RecordingTab extends ConsumerStatefulWidget {
  const RecordingTab({super.key});

  @override
  ConsumerState<RecordingTab> createState() => _RecordingTabState();
}

class _RecordingTabState extends ConsumerState<RecordingTab> {
  bool _cleaning = false;

  Future<void> _cleanupNow(int retentionDays) async {
    setState(() => _cleaning = true);
    try {
      await bridge.recordingCleanupExpired(days: retentionDays);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).recordingCleanupDone),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).recordingCleanupFailed(e.toString())),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final s = state.settings;
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(TermexSpacing.xl),
      children: [
        _SectionHeader(label: AppLocalizations.of(context).recordingSaveSettings),
        const SizedBox(height: TermexSpacing.md),
        _RetentionSlider(
          value: s.recordingRetentionDays,
          onChanged: (v) =>
              notifier.update(s.copyWith(recordingRetentionDays: v)),
        ),
        const SizedBox(height: TermexSpacing.xl),
        _SectionHeader(label: AppLocalizations.of(context).recordingFormat),
        const SizedBox(height: TermexSpacing.md),
        _FormatCard(
          title: 'Asciinema (.cast)',
          subtitle: AppLocalizations.of(context).recordingFormatJsonSubtitle,
          icon: Icons.play_circle_outline,
          selected: s.recordingFormat == 'asciinema',
          onTap: () => notifier.update(s.copyWith(recordingFormat: 'asciinema')),
        ),
        const SizedBox(height: TermexSpacing.sm),
        _FormatCard(
          title: 'Raw Terminal (.log)',
          subtitle: AppLocalizations.of(context).recordingFormatRawSubtitle,
          icon: Icons.article_outlined,
          selected: s.recordingFormat == 'raw',
          onTap: () => notifier.update(s.copyWith(recordingFormat: 'raw')),
        ),
        const SizedBox(height: TermexSpacing.xl),
        _InfoBox(message: AppLocalizations.of(context).recordingStorageNote),
        const SizedBox(height: TermexSpacing.lg),
        _CleanupButton(
          loading: _cleaning,
          onTap: () => _cleanupNow(s.recordingRetentionDays),
        ),
      ],
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TermexTypography.bodySmall.copyWith(
        color: context.colors.textMuted,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _RetentionSlider extends StatelessWidget {
  final int value;
  final void Function(int) onChanged;

  const _RetentionSlider({required this.value, required this.onChanged});

  String _label(int days, AppLocalizations l) {
    if (days == -1) return l.recordingRetentionForever;
    if (days == 0) return l.recordingRetentionNone;
    return l.recordingRetentionDays(days.toString());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Discrete steps: -1 (forever), 7, 30, 60, 90, 180, 365
    const steps = [-1, 7, 30, 60, 90, 180, 365];
    final idx = steps.indexOf(value).clamp(0, steps.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context).recordingRetentionTitle,
                style: TermexTypography.body
                    .copyWith(color: context.colors.textPrimary)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _label(value, l10n),
                style: TermexTypography.caption.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: idx.toDouble(),
          min: 0,
          max: (steps.length - 1).toDouble(),
          divisions: steps.length - 1,
          activeColor: context.colors.primary,
          inactiveColor: context.colors.border,
          onChanged: (v) => onChanged(steps[v.round()]),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context).recordingForever, style: TermexTypography.caption.copyWith(color: context.colors.textMuted)),
            Text(AppLocalizations.of(context).recordingOneYear, style: TermexTypography.caption.copyWith(color: context.colors.textMuted)),
          ],
        ),
      ],
    );
  }
}

class _FormatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FormatCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? context.colors.primary : context.colors.border;
    final bgColor = selected
        ? context.colors.primary.withValues(alpha: 0.08)
        : context.colors.backgroundTertiary;

    return Clickable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(TermexSpacing.md),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 18,
                color:
                    selected ? context.colors.primary : context.colors.textSecondary),
            const SizedBox(width: TermexSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TermexTypography.body.copyWith(
                        color: selected
                            ? context.colors.primary
                            : context.colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TermexTypography.caption
                          .copyWith(color: context.colors.textMuted)),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: selected,
              onChanged: (_) => onTap(),
              activeColor: context.colors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _CleanupButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _CleanupButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.colors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: context.colors.warning),
              )
            else
              Icon(Icons.cleaning_services_outlined,
                  size: 14, color: context.colors.warning),
            const SizedBox(width: 6),
            Text(
              loading ? AppLocalizations.of(context).recordingCleanupRunning : AppLocalizations.of(context).recordingCleanupNow,
              style: TermexTypography.body.copyWith(
                color: context.colors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String message;
  const _InfoBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TermexSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: context.colors.primary),
          const SizedBox(width: TermexSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TermexTypography.caption
                  .copyWith(color: context.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
