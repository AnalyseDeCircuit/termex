/// Background poller that translates daemon-side task events into
/// [TaskEvent]s on the [TaskEventBus] (v0.79.22).
///
/// Lifecycle:
///   1. Caller obtains a `handleId` via `daemon_connect` (out of scope —
///      v0.79.23 will wire mobile-side daemon connect/discovery).
///   2. Caller calls `daemonSubscribe(handleId, taskId)` for every task to
///      track.
///   3. Calls [DaemonTaskEventPoller.start] with the handle id.
///   4. The poller drains events on a 1 s interval, converts `status` /
///      `awaiting_input` events into [TaskEvent]s, and publishes to the bus.
///   5. [DaemonTaskEventPoller.stop] cancels the timer + clears the cache.
///
/// **Not auto-started in v0.79.22** — mobile UI hasn't connected to a
/// daemon yet. The poller infrastructure lives here so v0.79.23 can wire
/// the connection lifecycle without redesigning the event pipeline.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
// ignore: implementation_imports
import 'package:termex_bridge/src/api.dart' as frb;

import 'mobile_localizer.dart';
import 'task_event_bus.dart';

/// Wraps the daemon drain loop. One instance per `handleId` — multiple
/// daemon handles (eg. multiple SSH sessions to different termexd hosts)
/// each get their own poller.
class DaemonTaskEventPoller {
  DaemonTaskEventPoller({
    required this.handleId,
    this.pollInterval = const Duration(seconds: 1),
    this.maxEventsPerDrain = 64,
    TaskEventBus? bus,
  }) : _bus = bus ?? TaskEventBus.instance;

  final String handleId;
  final Duration pollInterval;
  final int maxEventsPerDrain;
  final TaskEventBus _bus;

  Timer? _timer;

  /// Per-task title cache. Sources that know the title (eg. the page that
  /// started the task) call [registerTaskTitle] before subscribing; the
  /// poller uses the cache when translating raw daemon events into
  /// [TaskEvent]s. Falls back to taskId if the title is unknown.
  final Map<String, String> _titles = {};

  /// Tracks per-task whether we've already published a terminal event.
  /// Daemon may replay events on re-subscribe; we silently drop duplicates
  /// so the notification dispatcher doesn't double-fire.
  final Set<String> _terminalDelivered = {};

  bool get isRunning => _timer != null && _timer!.isActive;

  /// Register a human-readable title for a task. Call before subscribing
  /// so the first published event has a useful label.
  void registerTaskTitle(String taskId, String title) {
    _titles[taskId] = title;
  }

  void clearTaskTitle(String taskId) {
    _titles.remove(taskId);
    _terminalDelivered.remove(taskId);
  }

  Future<void> start() async {
    if (isRunning) return;
    _timer = Timer.periodic(pollInterval, (_) => _tick());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    List<frb.DaemonEvent> events;
    try {
      events = await frb.daemonDrainEvents(
        handleId: handleId,
        maxEvents: maxEventsPerDrain,
      );
    } catch (e) {
      debugPrint('DaemonTaskEventPoller drain failed: $e');
      return;
    }
    for (final raw in events) {
      final translated = _translate(raw);
      if (translated != null) {
        if (translated.status.isTerminal) {
          if (_terminalDelivered.contains(translated.taskId)) continue;
          _terminalDelivered.add(translated.taskId);
        }
        _bus.publish(translated);
      }
    }
  }

  /// Best-effort translation. Returns null for events we don't surface
  /// (output chunks, tool-use traces, etc — those go to the in-app task
  /// view, not the notification primitive).
  TaskEvent? _translate(frb.DaemonEvent raw) {
    if (raw.kind != 'status') return null;
    final mapped = _mapStatus(raw.status);
    if (mapped == null) return null;
    final title = _titles[raw.taskId] ?? 'Task ${raw.taskId}';
    return TaskEvent(
      taskId: raw.taskId,
      title: title,
      summary: _summaryFor(mapped, raw.exitCode),
      status: mapped,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(raw.tsMs.toInt()),
    );
  }

  static TaskEventStatus? _mapStatus(frb.TaskStatusDto? s) {
    if (s == null) return null;
    return switch (s) {
      frb.TaskStatusDto.pending => TaskEventStatus.pending,
      frb.TaskStatusDto.pendingConfirmation =>
        TaskEventStatus.pendingConfirmation,
      frb.TaskStatusDto.running => TaskEventStatus.running,
      frb.TaskStatusDto.succeeded => TaskEventStatus.succeeded,
      frb.TaskStatusDto.failed => TaskEventStatus.failed,
      frb.TaskStatusDto.cancelled => TaskEventStatus.cancelled,
    };
  }

  /// Default summary text. Sources can override by constructing
  /// [TaskEvent] directly + publishing to the bus themselves.
  ///
  /// v0.79.28: consults [MobileLocalizer.current] for the user's locale.
  /// Falls back to English when the localizer hasn't built yet (very
  /// first frame race; should never happen in practice since the poller
  /// only starts after a daemon handle exists, which means the user has
  /// already navigated past the splash).
  static String _summaryFor(TaskEventStatus status, int? exitCode) {
    final l10n = MobileLocalizer.current;
    if (l10n == null) {
      // Fallback to English — the rare cold-path before first frame.
      switch (status) {
        case TaskEventStatus.succeeded:
          return 'Task completed successfully';
        case TaskEventStatus.failed:
          return exitCode != null
              ? 'Task failed (exit $exitCode)'
              : 'Task failed';
        case TaskEventStatus.cancelled:
          return 'Task cancelled';
        case TaskEventStatus.running:
          return 'Task started';
        case TaskEventStatus.pending:
          return 'Task queued';
        case TaskEventStatus.pendingConfirmation:
          return 'Task awaiting confirmation';
      }
    }
    switch (status) {
      case TaskEventStatus.succeeded:
        return l10n.taskPollerSummarySucceeded;
      case TaskEventStatus.failed:
        return exitCode != null
            ? l10n.taskPollerSummaryFailedWithExit(exitCode)
            : l10n.taskPollerSummaryFailed;
      case TaskEventStatus.cancelled:
        return l10n.taskPollerSummaryCancelled;
      case TaskEventStatus.running:
        return l10n.taskPollerSummaryRunning;
      case TaskEventStatus.pending:
        return l10n.taskPollerSummaryPending;
      case TaskEventStatus.pendingConfirmation:
        return l10n.taskPollerSummaryAwaitingConfirmation;
    }
  }
}
