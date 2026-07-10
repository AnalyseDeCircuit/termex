/// Category bucket inferred from a [TaskEvent.taskId] prefix (v0.79.35).
///
/// Used by the history page filter chips so the user can narrow to "all
/// SFTP transfers" / "all AI replies" without the bus or sources needing
/// to know about UI categorisation. The prefix contract is established
/// at emission time (see SftpTransferNotifier → "sftp-…",
/// AiStreamNotifier → "ai-…"); adding a new source just requires
/// extending this enum + helper.
library;

import 'task_event_bus.dart';

enum TaskSource {
  sftp,
  ai,
  other,
}

extension TaskSourceX on TaskSource {
  /// Stable id used in persisted UI state. Keep in sync with [parse].
  String get id => switch (this) {
        TaskSource.sftp => 'sftp',
        TaskSource.ai => 'ai',
        TaskSource.other => 'other',
      };

  static TaskSource? parse(String id) => switch (id) {
        'sftp' => TaskSource.sftp,
        'ai' => TaskSource.ai,
        'other' => TaskSource.other,
        _ => null,
      };
}

/// Infer the source category for a task event by looking at the
/// `taskId` prefix. Unknown / empty prefixes bucket under
/// [TaskSource.other].
///
/// Rationale for prefix-derivation rather than a stored field on
/// [TaskEvent]: keeps the persisted snapshot schema unchanged — adding
/// this categorisation to v0.79.32-34 history records would have
/// required a fromJson migration. Prefix lives in taskId which is
/// already serialised, so we get the category for free.
TaskSource taskSourceOf(TaskEvent event) =>
    taskSourceOfId(event.taskId);

TaskSource taskSourceOfId(String taskId) {
  if (taskId.startsWith('sftp-')) return TaskSource.sftp;
  if (taskId.startsWith('ai-')) return TaskSource.ai;
  return TaskSource.other;
}
