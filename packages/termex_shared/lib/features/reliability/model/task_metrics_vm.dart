/// View-model mirror of `termex_core::reliability::TaskMetrics`.
/// Kept independent of FRB so widget tests can construct fixtures
/// without a database round-trip.
library;

class TaskMetricsVM {
  final String taskId;
  final int wsUptimeMs;
  final int reconnectCount;
  final int bgDurationMs;
  /// Last observed end-to-end push latency, ms. `null` when no push
  /// has landed yet for this task.
  final int? pushLatencyMs;
  final int handoffCount;
  final DateTime updatedAt;

  const TaskMetricsVM({
    required this.taskId,
    required this.wsUptimeMs,
    required this.reconnectCount,
    required this.bgDurationMs,
    required this.pushLatencyMs,
    required this.handoffCount,
    required this.updatedAt,
  });

  factory TaskMetricsVM.empty(String taskId, {DateTime? now}) => TaskMetricsVM(
        taskId: taskId,
        wsUptimeMs: 0,
        reconnectCount: 0,
        bgDurationMs: 0,
        pushLatencyMs: null,
        handoffCount: 0,
        updatedAt: now ?? DateTime.now(),
      );
}

/// Reconnect state for a single daemon connection. The widget
/// caller maintains the timer + transitions; this struct is the
/// snapshot the banner renders.
enum ReconnectStatusVM {
  connected,
  reconnecting,
  failed;
}

class ReconnectAttemptVM {
  final String serverId;
  final String serverLabel;
  final ReconnectStatusVM status;
  /// Optional human reason — shown beside the server label when set.
  final String? note;
  const ReconnectAttemptVM({
    required this.serverId,
    required this.serverLabel,
    required this.status,
    this.note,
  });
}

/// Format ms as a compact human duration: `350ms` / `5.4s` /
/// `2m 14s` / `1h 30m`. Used by ReliabilityFooter so the row stays
/// readable even when a task has been running for days.
String formatDurationMs(int ms) {
  if (ms < 1000) return '${ms}ms';
  final secs = ms / 1000;
  if (secs < 60) return '${secs.toStringAsFixed(1)}s';
  final mins = secs / 60;
  if (mins < 60) {
    final m = mins.floor();
    final s = (secs - m * 60).round();
    return '${m}m ${s}s';
  }
  final hours = mins / 60;
  final h = hours.floor();
  final m = (mins - h * 60).round();
  return '${h}h ${m}m';
}
