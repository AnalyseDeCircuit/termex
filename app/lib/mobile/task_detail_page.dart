/// Mobile task detail page (v0.79.23 skeleton).
///
/// Reached via:
///   - Tapping a local notification (deep link, payload = taskId).
///   - Future: tapping a task row in a task-history list (v0.79.24+).
///
/// This iteration ships the **skeleton**: title / status badge / summary /
/// taskId. Output tail, artifacts, MCP tool-use trace, AI usage stats are
/// all placeholders — they wire up once the daemon task event stream
/// (v0.79.24+) feeds richer data into [TaskEventBus].
library;

import 'package:flutter/widgets.dart';
import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/design/spacing.dart';
import 'package:termex_shared/design/typography.dart';
import 'package:termex_shared/icons/termex_icons.dart';
import 'package:termex_shared/l10n/app_localizations.dart';
import 'package:termex_shared/widgets/clickable.dart';

import 'task_event_bus.dart';

class MobileTaskDetailPage extends StatelessWidget {
  /// The taskId carried in the notification payload. Resolved against
  /// [TaskEventBus.latestFor] to hydrate. If no event was published yet
  /// for this id (eg. push from a server we haven't synced), the page
  /// still renders with the bare id so the user knows what they tapped.
  final String taskId;

  const MobileTaskDetailPage({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final event = TaskEventBus.instance.latestFor(taskId);
    return Container(
      color: context.colors.backgroundPrimary,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(taskId: taskId),
            const SizedBox(height: TermexSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TitleBlock(event: event, taskId: taskId, l10n: l10n),
                    const SizedBox(height: TermexSpacing.md),
                    _StatusRow(event: event, l10n: l10n),
                    const SizedBox(height: TermexSpacing.lg),
                    _SummaryBlock(event: event, l10n: l10n),
                    const SizedBox(height: TermexSpacing.xl),
                    _PendingSection(
                      label: l10n.taskDetailOutputComingSoon,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          Clickable(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                TermexIcons.close,
                size: 20,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              l10n.taskDetailHeader,
              style: TermexTypography.body.copyWith(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.event, required this.taskId, required this.l10n});
  final TaskEvent? event;
  final String taskId;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event?.title ?? l10n.taskDetailUnknownTask,
          style: TermexTypography.heading3.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          taskId,
          style: TermexTypography.caption.copyWith(
            color: context.colors.textMuted,
            fontFamily: 'JetBrainsMono',
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.event, required this.l10n});
  final TaskEvent? event;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (event == null) {
      return _Pill(
        label: l10n.taskDetailStatusUnknown,
        color: context.colors.textMuted,
      );
    }
    final color = switch (event!.status) {
      TaskEventStatus.succeeded => context.colors.success,
      TaskEventStatus.failed => context.colors.danger,
      TaskEventStatus.cancelled => context.colors.warning,
      TaskEventStatus.running => context.colors.primary,
      TaskEventStatus.pending => context.colors.textMuted,
      TaskEventStatus.pendingConfirmation => context.colors.warning,
    };
    final label = switch (event!.status) {
      TaskEventStatus.succeeded => l10n.taskDetailStatusSucceeded,
      TaskEventStatus.failed => l10n.taskDetailStatusFailed,
      TaskEventStatus.cancelled => l10n.taskDetailStatusCancelled,
      TaskEventStatus.running => l10n.taskDetailStatusRunning,
      TaskEventStatus.pending => l10n.taskDetailStatusPending,
      TaskEventStatus.pendingConfirmation =>
        l10n.taskDetailStatusAwaitingConfirmation,
    };
    return _Pill(label: label, color: color);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TermexTypography.caption.copyWith(color: color),
        ),
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.event, required this.l10n});
  final TaskEvent? event;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final text = event?.summary ?? l10n.taskDetailNoSummary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TermexTypography.body.copyWith(
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}

/// Placeholder section for future content (output tail, artifacts, MCP
/// tool-use trace, AI usage stats). v0.79.23 ships the slot only.
class _PendingSection extends StatelessWidget {
  const _PendingSection({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: context.colors.border,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TermexTypography.caption.copyWith(color: context.colors.textMuted),
      ),
    );
  }
}
