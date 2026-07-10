/// Cross-package sink for "task completed" emissions (v0.79.25).
///
/// Bridges shared feature code (SFTP transfers, future AI streams, …) to
/// the mobile-only [TaskEventBus] living in `app/lib/mobile/`. Without
/// this indirection `termex_shared` would either have to import the
/// mobile package (a layering violation — shared can't depend on app) or
/// give up on emitting task events from inside shared providers.
///
/// Usage:
///
/// ```dart
/// // app/lib/main.dart (mobile only):
/// TaskCompletionSink.register((evt) => TaskEventBus.instance.publish(
///   TaskEvent(...)));
///
/// // packages/termex_shared/lib/features/sftp/...:
/// TaskCompletionSink.emit(TaskCompletionPayload(
///   taskId: id,
///   title: 'Uploaded foo.tar.gz',
///   summary: 'Upload completed (12.4 MB)',
///   success: true,
/// ));
/// ```
///
/// If no callback is registered (desktop, widget tests), [emit] silently
/// drops the payload — the source code is otherwise unchanged.
library;

/// Wire-level snapshot of a task transition that wants to surface in
/// notifications and history. Source-agnostic; the registered sink
/// callback decides how to render it.
class TaskCompletionPayload {
  /// Stable identifier — used as the notification id and history key.
  final String taskId;

  /// Human-friendly headline (eg. `Uploaded foo.tar.gz`). Pre-formatted
  /// by the source as an **English fallback** — sinks with access to a
  /// localizer (eg. the mobile app's main.dart callback) should prefer
  /// [kind] + [data] for proper l10n.
  final String title;

  /// Longer one-line summary (eg. `Upload completed (12.4 MB)`). Empty
  /// string is acceptable; the rendering layer falls back to "No summary
  /// available yet." Same fallback-only semantics as [title].
  final String summary;

  /// True for success states (`succeeded`), false for failure /
  /// cancellation. Sources that distinguish failure vs cancellation can
  /// encode that in the summary text.
  final bool success;

  /// v0.79.28: structured kind tag so sinks can route to a localized
  /// formatter. Optional — null means the sink should use [title] /
  /// [summary] as-is. Format is `<source>.<event>` (eg.
  /// `sftp.upload.succeeded`, `sftp.download.cancelled`).
  final String? kind;

  /// v0.79.28: structured params for the localizer. Keys depend on
  /// [kind]; eg. SFTP transfers populate `fileName`, `totalBytes`,
  /// `transferredBytes`, `errorMessage`.
  final Map<String, Object?> data;

  const TaskCompletionPayload({
    required this.taskId,
    required this.title,
    required this.summary,
    required this.success,
    this.kind,
    this.data = const {},
  });
}

typedef TaskCompletionCallback = void Function(TaskCompletionPayload payload);

/// Static registry. Implemented as a module-level singleton because
/// emission sites live deep inside Riverpod notifiers — passing the sink
/// through every `Ref` would force every provider in the tree to declare
/// a dependency on a UI-layer concern.
class TaskCompletionSink {
  TaskCompletionSink._();

  static TaskCompletionCallback? _callback;

  /// Install the sink. Call once during app boot before any source has
  /// a chance to emit. Subsequent calls replace the previous callback —
  /// only one sink is supported (consumers wanting fan-out should do so
  /// inside their callback).
  static void register(TaskCompletionCallback? callback) {
    _callback = callback;
  }

  /// Publish a payload. Silently dropped when no callback is registered
  /// (desktop builds, widget tests).
  static void emit(TaskCompletionPayload payload) {
    final cb = _callback;
    if (cb == null) return;
    cb(payload);
  }
}
