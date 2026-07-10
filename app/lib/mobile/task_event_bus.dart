/// Mobile task event bus (v0.79.22).
///
/// Decouples task event **sources** (daemon poller, future SSH command
/// trackers, future cloud sync handlers) from **sinks** (local notification
/// dispatcher, in-app banner queue, analytics).
///
/// Architecture:
///
///   [ DaemonTaskEventPoller ]
///   [ <future: SSH idle detector> ]   ──publish──►  TaskEventBus
///   [ <future: cloud webhook>     ]                       │
///                                                          ▼
///                                        ─subscribe──  MobileTaskNotifier
///                                                      <future: in-app banner>
///                                                      <future: analytics>
///
/// This is *not* a riverpod provider on purpose — the bus must outlive any
/// particular UI scope and remain available even when no widget is mounted
/// (so background notification triggers continue to work after the app is
/// suspended and resumed).
library;

import 'dart:async';

/// Lifecycle status for a tracked task. Mirrors the daemon wire-level
/// enum but stays Dart-side to avoid coupling consumers to FRB types.
enum TaskEventStatus {
  pending,
  pendingConfirmation,
  running,
  succeeded,
  failed,
  cancelled,
}

extension TaskEventStatusExt on TaskEventStatus {
  /// Terminal = no further transitions; safe to surface as "done".
  bool get isTerminal =>
      this == TaskEventStatus.succeeded ||
      this == TaskEventStatus.failed ||
      this == TaskEventStatus.cancelled;
}

/// One task-lifecycle event. `title` / `summary` are pre-resolved strings —
/// sources that pull from a registry (taskId → title) are responsible for
/// looking them up *before* publishing, since sinks may run after the
/// originating widget tree has been torn down.
class TaskEvent {
  final String taskId;
  final String title;
  final String summary;
  final TaskEventStatus status;

  /// Optional millisecond timestamp from the source (e.g. daemon `ts_ms`).
  /// Defaults to `DateTime.now()` at construction for synthesised events.
  final DateTime occurredAt;

  /// v0.79.29: whether this event should trigger an **OS notification**.
  /// Defaults to true. Sources / sink callbacks set it to false when an
  /// event is too trivial to interrupt the user — for example, a sub-MB
  /// or sub-3s SFTP transfer. History / dashboard sinks ignore this
  /// flag; only [MobileTaskNotifier] reads it.
  final bool notify;

  TaskEvent({
    required this.taskId,
    required this.title,
    required this.summary,
    required this.status,
    DateTime? occurredAt,
    this.notify = true,
  }) : occurredAt = occurredAt ?? DateTime.now();

  /// Serializes to a compact JSON-ready map for SharedPreferences storage
  /// (v0.79.26). Schema versioning lives at the [TaskHistoryStore] level —
  /// individual events stay schema-less so callers can upgrade the
  /// envelope without touching emission sites.
  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'title': title,
        'summary': summary,
        'status': status.name,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
      };

  /// Reverse of [toJson]. Returns null when any required field is missing
  /// or the status string doesn't match the current enum — defensive so
  /// a stale on-disk snapshot from a future version drops gracefully.
  static TaskEvent? fromJson(Map<String, dynamic> j) {
    final taskId = j['taskId'];
    final title = j['title'];
    final summary = j['summary'];
    final statusRaw = j['status'];
    final occurredAtRaw = j['occurredAt'];
    if (taskId is! String || title is! String || summary is! String) {
      return null;
    }
    if (statusRaw is! String || occurredAtRaw is! String) return null;
    final status = TaskEventStatus.values
        .where((s) => s.name == statusRaw)
        .firstOrNull;
    if (status == null) return null;
    final occurredAt = DateTime.tryParse(occurredAtRaw);
    if (occurredAt == null) return null;
    return TaskEvent(
      taskId: taskId,
      title: title,
      summary: summary,
      status: status,
      occurredAt: occurredAt,
    );
  }
}

/// Optional persistence backend. Implementations save the [latestSnapshot]
/// across app launches. The bus stays agnostic to the backing store so
/// widget tests can pass a no-op or in-memory fake.
abstract class TaskHistoryPersistence {
  Future<Map<String, TaskEvent>> load();
  Future<void> save(Map<String, TaskEvent> snapshot);
}

/// Singleton broadcast channel. Subscribers attach via [stream]; sources
/// emit via [publish]. The underlying [StreamController] is broadcast so
/// late subscribers do not block the source.
class TaskEventBus {
  TaskEventBus._();
  static final TaskEventBus instance = TaskEventBus._();

  final _controller = StreamController<TaskEvent>.broadcast();
  final _snapshotController = StreamController<void>.broadcast();
  TaskHistoryPersistence? _persistence;

  /// Schedules a debounced save after each publish — sources that fire
  /// many events in rapid succession (eg. an SFTP transfer reporting
  /// progress while in `inProgress` state) only flush to disk once the
  /// last event settles.
  Timer? _saveTimer;
  static const _saveDebounce = Duration(milliseconds: 500);

  /// Hot stream of task events. Subscribers added after a `publish()` call
  /// won't receive that earlier event — sinks that need replay should
  /// maintain their own buffer.
  ///
  /// Only real `publish()` calls emit here; `remove()` / `clearAll()`
  /// surface through [snapshotChanges] instead, so sinks like
  /// `MobileTaskNotifier` don't fire OS notifications for delete actions.
  Stream<TaskEvent> get stream => _controller.stream;

  /// Fires whenever the snapshot mutates (publish / remove / clearAll).
  /// Consumers that render the whole list — eg. [MobileTaskHistoryPage] —
  /// listen here so they rebuild on any structural change without having
  /// to interpret synthetic events on [stream].
  Stream<void> get snapshotChanges => _snapshotController.stream;

  /// Latest event seen per `taskId`. Populated by every [publish] call so
  /// deep-link consumers (eg. [MobileTaskDetailPage]) can resolve a task
  /// without having been subscribed when the event arrived. v0.79.23.
  final Map<String, TaskEvent> _latest = {};

  /// Returns the most recent event for [taskId], or null if the bus has
  /// not seen one yet. Useful for hydrating the task detail page when the
  /// user taps a notification (the subscriber wasn't around when the
  /// event was originally published).
  TaskEvent? latestFor(String taskId) => _latest[taskId];

  /// Read-only snapshot of every task the bus has ever seen, keyed by
  /// taskId. Consumers (eg. [MobileTaskHistoryPage]) iterate the values
  /// to build a chronological list. The map is unmodifiable; subscribe to
  /// [stream] for live updates.
  Map<String, TaskEvent> get latestSnapshot => Map.unmodifiable(_latest);

  /// Emit a new task event to all current subscribers.
  void publish(TaskEvent event) {
    if (_controller.isClosed) return;
    _latest[event.taskId] = event;
    _controller.add(event);
    _emitSnapshotChange();
    _scheduleSave();
  }

  /// Drop a single task from the bus snapshot. Used by the history page's
  /// long-press delete (v0.79.27). Surfaces on [snapshotChanges] so the
  /// list rebuilds; not on [stream] so `MobileTaskNotifier` doesn't
  /// re-fire an OS notification for the deleted task.
  void remove(String taskId) {
    if (_latest.remove(taskId) == null) return;
    _emitSnapshotChange();
    _scheduleSave();
  }

  /// Put an event back into the snapshot — the inverse of [remove]. Used
  /// by the history page's 5-second undo banner (v0.79.32). Emits on
  /// [snapshotChanges] so the list rebuilds, but **not** on [stream] —
  /// re-publishing through the public surface would let
  /// `MobileTaskNotifier` fire a duplicate OS notification for the
  /// already-acknowledged event.
  ///
  /// If a newer event with the same taskId arrived between remove and
  /// restore (rare but possible — eg. SFTP retry), the newer event
  /// wins; restore is a no-op.
  void restore(TaskEvent event) {
    if (_latest.containsKey(event.taskId)) return;
    _latest[event.taskId] = event;
    _emitSnapshotChange();
    _scheduleSave();
  }

  /// Bulk inverse of [clearAll] (v0.79.33). Merges the given snapshot
  /// back into [_latest] — events whose taskId has a newer arrival
  /// during the undo window are NOT overwritten (same race-protection
  /// semantics as [restore]). Fires a single [snapshotChanges] tick at
  /// the end so the history rebuilds once. Does not fire on [stream].
  void restoreAll(Map<String, TaskEvent> snapshot) {
    if (snapshot.isEmpty) return;
    var inserted = 0;
    for (final entry in snapshot.entries) {
      if (_latest.containsKey(entry.key)) continue;
      _latest[entry.key] = entry.value;
      inserted++;
    }
    if (inserted == 0) return;
    _emitSnapshotChange();
    _scheduleSave();
  }

  /// Wipe the entire snapshot. Persistence flushes the empty map on the
  /// next debounce tick. Surfaces on [snapshotChanges] only.
  void clearAll() {
    if (_latest.isEmpty) return;
    _latest.clear();
    _emitSnapshotChange();
    _scheduleSave();
  }

  /// v0.79.41: drop a *set* of tasks from the snapshot. Symmetric with
  /// [restoreAll]: one [snapshotChanges] tick at the end so the list
  /// rebuilds once. Used by the history page's "Clear filtered" action
  /// — clearing N rows that match the current chip / search predicate
  /// without touching unrelated entries.
  ///
  /// Returns the events actually removed (intersection of [taskIds] with
  /// the current snapshot). Callers stash these for the undo banner.
  Map<String, TaskEvent> removeMany(Iterable<String> taskIds) {
    final removed = <String, TaskEvent>{};
    for (final id in taskIds) {
      final prior = _latest.remove(id);
      if (prior != null) removed[id] = prior;
    }
    if (removed.isEmpty) return removed;
    _emitSnapshotChange();
    _scheduleSave();
    return removed;
  }

  void _emitSnapshotChange() {
    if (_snapshotController.isClosed) return;
    _snapshotController.add(null);
  }

  /// Wires a persistence backend. Call once at app startup before any
  /// source publishes — typically from `main.dart` after the bus has had
  /// a chance to [hydrate] from disk.
  void attachPersistence(TaskHistoryPersistence persistence) {
    _persistence = persistence;
  }

  /// Loads the last persisted snapshot into [_latest] without emitting on
  /// the stream — the saved events already fired notifications in the
  /// previous session, replaying them now would double-fire. Subscribers
  /// see the rehydrated state via [latestFor] / [latestSnapshot].
  Future<void> hydrate() async {
    final persistence = _persistence;
    if (persistence == null) return;
    try {
      final loaded = await persistence.load();
      _latest.addAll(loaded);
    } catch (_) {
      // Corrupt / unreadable snapshot is non-fatal — the user just
      // starts the session with an empty history.
    }
  }

  void _scheduleSave() {
    final persistence = _persistence;
    if (persistence == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () {
      _saveTimer = null;
      // ignore: discarded_futures
      persistence.save(Map.of(_latest));
    });
  }

  /// Test-only: tears down the controllers. Production code never closes
  /// the singleton.
  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
    if (!_snapshotController.isClosed) await _snapshotController.close();
  }
}
