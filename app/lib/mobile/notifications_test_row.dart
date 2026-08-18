/// Mobile-only test row for the local-notification primitive (v0.79.55,
/// originally added in v0.79.21).
///
/// Surfaces two affordances above the cross-platform thresholds:
///   1. "Send test notification" — directly fires a notification through
///      [MobileTaskNotifier] so the user can self-test permission state.
///   2. "Fire demo task event" — publishes a synthetic [TaskEvent] on
///      [TaskEventBus] so the user can verify the bus → notifier
///      pipeline end-to-end (notifier auto-subscribes during init).
///
/// Lives in `app/lib/mobile/` because [MobileTaskNotifier] +
/// [TaskEventBus] live there; the shared NotificationsTab takes this as
/// an optional `header:` widget so desktop renders the thresholds alone.
library;

import 'package:flutter/widgets.dart';
import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/design/spacing.dart';
import 'package:termex_shared/design/typography.dart';
import 'package:termex_shared/l10n/app_localizations.dart';
import 'package:termex_shared/widgets/clickable.dart';

import 'task_event_bus.dart';
import 'task_notifier.dart';

class NotificationsTestRow extends StatefulWidget {
  const NotificationsTestRow({super.key});

  @override
  State<NotificationsTestRow> createState() => _NotificationsTestRowState();
}

class _NotificationsTestRowState extends State<NotificationsTestRow> {
  bool _firing = false;
  String? _feedback;
  bool _ok = true;

  Future<void> _onTest() async {
    if (_firing) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _firing = true);
    final granted = await MobileTaskNotifier.instance.ensurePermission();
    if (!granted) {
      if (mounted) {
        setState(() {
          _firing = false;
          _ok = false;
          _feedback = l10n.notificationsTestDenied;
        });
      }
      return;
    }
    await MobileTaskNotifier.instance.notifyTaskComplete(
      taskId: 'test-${DateTime.now().millisecondsSinceEpoch}',
      title: l10n.notificationsTestTitle,
      body: l10n.notificationsTestBody,
    );
    if (mounted) {
      setState(() {
        _firing = false;
        _ok = true;
        _feedback = l10n.notificationsTestSent;
      });
    }
  }

  /// v0.79.22: publish a synthetic [TaskEvent] to verify the bus → notifier
  /// path. The notifier auto-subscribes to the bus during `init()`, so
  /// publishing a terminal-status event fires a notification with zero
  /// additional wiring at this call site.
  Future<void> _onDemoTaskEvent() async {
    if (_firing) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _firing = true);
    final granted = await MobileTaskNotifier.instance.ensurePermission();
    if (!granted) {
      if (mounted) {
        setState(() {
          _firing = false;
          _ok = false;
          _feedback = l10n.notificationsTestDenied;
        });
      }
      return;
    }
    TaskEventBus.instance.publish(
      TaskEvent(
        taskId: 'demo-${DateTime.now().millisecondsSinceEpoch}',
        title: l10n.notificationsDemoTaskTitle,
        summary: l10n.notificationsDemoTaskSummary,
        status: TaskEventStatus.succeeded,
      ),
    );
    if (mounted) {
      setState(() {
        _firing = false;
        _ok = true;
        _feedback = l10n.notificationsDemoTaskSent;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.notificationsSectionTitle,
                  style: TermexTypography.body.copyWith(
                    color: TermexColors.textPrimary,
                  ),
                ),
              ),
              Clickable(
                behavior: HitTestBehavior.opaque,
                onTap: _firing ? null : _onTest,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    l10n.notificationsTestButton,
                    style: TermexTypography.body.copyWith(
                      color: _firing
                          ? TermexColors.textMuted
                          : TermexColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TermexSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Clickable(
              behavior: HitTestBehavior.opaque,
              onTap: _firing ? null : _onDemoTaskEvent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  l10n.notificationsDemoTaskButton,
                  style: TermexTypography.body.copyWith(
                    color: _firing
                        ? TermexColors.textMuted
                        : TermexColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: TermexSpacing.xs),
            Text(
              _feedback!,
              style: TermexTypography.caption.copyWith(
                color: _ok ? TermexColors.success : TermexColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
