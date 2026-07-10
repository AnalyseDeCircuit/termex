/// Unit tests for [TaskEventBus] and [TaskEventStatusExt.isTerminal]
/// (v0.79.22).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:termex/mobile/task_event_bus.dart';

void main() {
  group('TaskEventStatus.isTerminal', () {
    test('succeeded / failed / cancelled are terminal', () {
      expect(TaskEventStatus.succeeded.isTerminal, isTrue);
      expect(TaskEventStatus.failed.isTerminal, isTrue);
      expect(TaskEventStatus.cancelled.isTerminal, isTrue);
    });

    test('pending / running / awaiting confirmation are not terminal', () {
      expect(TaskEventStatus.pending.isTerminal, isFalse);
      expect(TaskEventStatus.pendingConfirmation.isTerminal, isFalse);
      expect(TaskEventStatus.running.isTerminal, isFalse);
    });
  });

  group('TaskEventBus', () {
    test('publish reaches all current subscribers', () async {
      final bus = TaskEventBus.instance;
      final seen = <String>[];
      final sub = bus.stream.listen((e) => seen.add(e.taskId));

      bus.publish(TaskEvent(
        taskId: 't1',
        title: 'one',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      bus.publish(TaskEvent(
        taskId: 't2',
        title: 'two',
        summary: 's',
        status: TaskEventStatus.failed,
      ));

      // Allow async event loop to drain the stream.
      await Future<void>.delayed(Duration.zero);

      expect(seen, ['t1', 't2']);
      await sub.cancel();
    });

    test('late subscribers do not receive earlier events', () async {
      final bus = TaskEventBus.instance;
      bus.publish(TaskEvent(
        taskId: 'before',
        title: 'b',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      await Future<void>.delayed(Duration.zero);

      final seen = <String>[];
      final sub = bus.stream.listen((e) => seen.add(e.taskId));
      bus.publish(TaskEvent(
        taskId: 'after',
        title: 'a',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(seen, ['after']);
      await sub.cancel();
    });

    test('latestFor returns the most recent event per taskId', () async {
      final bus = TaskEventBus.instance;
      bus.publish(TaskEvent(
        taskId: 'late-1',
        title: 'first',
        summary: 's1',
        status: TaskEventStatus.running,
      ));
      bus.publish(TaskEvent(
        taskId: 'late-1',
        title: 'second',
        summary: 's2',
        status: TaskEventStatus.succeeded,
      ));
      bus.publish(TaskEvent(
        taskId: 'late-2',
        title: 'other',
        summary: 's',
        status: TaskEventStatus.failed,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(bus.latestFor('late-1')?.summary, 's2');
      expect(bus.latestFor('late-1')?.status, TaskEventStatus.succeeded);
      expect(bus.latestFor('late-2')?.status, TaskEventStatus.failed);
      expect(bus.latestFor('not-published'), isNull);
    });

    test('remove deletes a single task and emits snapshotChanges only', () async {
      final bus = TaskEventBus.instance;
      bus.publish(TaskEvent(
        taskId: 'rm-1',
        title: 't',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      bus.publish(TaskEvent(
        taskId: 'rm-2',
        title: 't',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      await Future<void>.delayed(Duration.zero);

      final eventsSeen = <String>[];
      var snapshotChanges = 0;
      final eventSub = bus.stream.listen((e) => eventsSeen.add(e.taskId));
      final snapSub = bus.snapshotChanges.listen((_) => snapshotChanges++);

      bus.remove('rm-1');
      await Future<void>.delayed(Duration.zero);

      // No TaskEvent on the publish stream — sinks like the notifier
      // should not re-fire OS notifications on delete.
      expect(eventsSeen, isEmpty);
      // snapshotChanges fired exactly once.
      expect(snapshotChanges, 1);
      // The removed task is gone; the other survives.
      expect(bus.latestFor('rm-1'), isNull);
      expect(bus.latestFor('rm-2'), isNotNull);

      await eventSub.cancel();
      await snapSub.cancel();
    });

    test('remove of unknown id is a no-op', () async {
      final bus = TaskEventBus.instance;
      var snapshotChanges = 0;
      final snapSub = bus.snapshotChanges.listen((_) => snapshotChanges++);

      bus.remove('does-not-exist');
      await Future<void>.delayed(Duration.zero);

      expect(snapshotChanges, 0);
      await snapSub.cancel();
    });

    test('clearAll wipes snapshot and emits snapshotChanges', () async {
      final bus = TaskEventBus.instance;
      bus.publish(TaskEvent(
        taskId: 'c-1',
        title: 't',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      bus.publish(TaskEvent(
        taskId: 'c-2',
        title: 't',
        summary: 's',
        status: TaskEventStatus.failed,
      ));
      await Future<void>.delayed(Duration.zero);

      final eventsSeen = <String>[];
      var snapshotChanges = 0;
      final eventSub = bus.stream.listen((e) => eventsSeen.add(e.taskId));
      final snapSub = bus.snapshotChanges.listen((_) => snapshotChanges++);

      bus.clearAll();
      await Future<void>.delayed(Duration.zero);

      expect(eventsSeen, isEmpty);
      expect(snapshotChanges, 1);
      expect(bus.latestSnapshot, isEmpty);

      await eventSub.cancel();
      await snapSub.cancel();
    });

    test('removeMany drops the requested subset and returns removed map',
        () async {
      final bus = TaskEventBus.instance;
      bus.clearAll();
      bus.publish(TaskEvent(
        taskId: 'rm-many-1',
        title: 'A',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      bus.publish(TaskEvent(
        taskId: 'rm-many-2',
        title: 'B',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      bus.publish(TaskEvent(
        taskId: 'rm-many-3',
        title: 'C',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      await Future<void>.delayed(Duration.zero);

      final eventsSeen = <String>[];
      var snapshotChanges = 0;
      final eventSub = bus.stream.listen((e) => eventsSeen.add(e.taskId));
      final snapSub = bus.snapshotChanges.listen((_) => snapshotChanges++);

      final removed = bus.removeMany(['rm-many-1', 'rm-many-3']);
      await Future<void>.delayed(Duration.zero);

      // Only the requested IDs are gone; #2 survives.
      expect(bus.latestFor('rm-many-1'), isNull);
      expect(bus.latestFor('rm-many-2')?.title, 'B');
      expect(bus.latestFor('rm-many-3'), isNull);
      // Snapshot tick fired exactly once for the whole bulk.
      expect(snapshotChanges, 1);
      // Stream untouched — clearing must not re-fire OS notifications.
      expect(eventsSeen, isEmpty);
      // Returned map contains exactly the events that were actually removed.
      expect(removed.keys.toSet(), {'rm-many-1', 'rm-many-3'});
      expect(removed['rm-many-1']?.title, 'A');
      expect(removed['rm-many-3']?.title, 'C');

      await eventSub.cancel();
      await snapSub.cancel();
    });

    test('removeMany ignores unknown ids and is no-op when none match',
        () async {
      final bus = TaskEventBus.instance;
      bus.clearAll();
      bus.publish(TaskEvent(
        taskId: 'rm-many-only',
        title: 'X',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      await Future<void>.delayed(Duration.zero);

      var snapshotChanges = 0;
      final snapSub = bus.snapshotChanges.listen((_) => snapshotChanges++);

      final removed = bus.removeMany(['ghost-1', 'ghost-2']);
      await Future<void>.delayed(Duration.zero);

      expect(removed, isEmpty);
      expect(snapshotChanges, 0);
      expect(bus.latestFor('rm-many-only')?.title, 'X');

      await snapSub.cancel();
    });

    test('removeMany + restoreAll round-trip preserves filtered subset', () async {
      final bus = TaskEventBus.instance;
      bus.clearAll();
      bus.publish(TaskEvent(
        taskId: 'roundtrip-1',
        title: 'A',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      bus.publish(TaskEvent(
        taskId: 'roundtrip-2',
        title: 'B',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      await Future<void>.delayed(Duration.zero);

      final removed = bus.removeMany(['roundtrip-1']);
      expect(bus.latestFor('roundtrip-1'), isNull);
      expect(bus.latestFor('roundtrip-2'), isNotNull);

      bus.restoreAll(removed);
      expect(bus.latestFor('roundtrip-1')?.title, 'A');
      expect(bus.latestFor('roundtrip-2')?.title, 'B');
    });

    test('clearAll on empty snapshot is a no-op', () async {
      final bus = TaskEventBus.instance;
      bus.clearAll();  // already cleared from previous test
      var snapshotChanges = 0;
      final snapSub = bus.snapshotChanges.listen((_) => snapshotChanges++);

      bus.clearAll();
      await Future<void>.delayed(Duration.zero);

      expect(snapshotChanges, 0);
      await snapSub.cancel();
    });

    test('restore re-adds event to snapshot without firing stream', () async {
      final bus = TaskEventBus.instance;
      bus.clearAll();
      final event = TaskEvent(
        taskId: 'undo-1',
        title: 'Important',
        summary: 's',
        status: TaskEventStatus.succeeded,
      );
      bus.publish(event);
      await Future<void>.delayed(Duration.zero);
      bus.remove('undo-1');
      await Future<void>.delayed(Duration.zero);
      expect(bus.latestFor('undo-1'), isNull);

      final eventsSeen = <String>[];
      var snapshotChanges = 0;
      final eventSub = bus.stream.listen((e) => eventsSeen.add(e.taskId));
      final snapSub = bus.snapshotChanges.listen((_) => snapshotChanges++);

      bus.restore(event);
      await Future<void>.delayed(Duration.zero);

      // Restore re-populates the snapshot.
      expect(bus.latestFor('undo-1')?.title, 'Important');
      // No TaskEvent on the publish stream — the OS notifier must not
      // re-fire for an undo action.
      expect(eventsSeen, isEmpty);
      // snapshotChanges fired so the history list refreshes.
      expect(snapshotChanges, 1);

      await eventSub.cancel();
      await snapSub.cancel();
    });

    test('restoreAll re-adds bulk snapshot without firing stream', () async {
      final bus = TaskEventBus.instance;
      bus.clearAll();
      final e1 = TaskEvent(
        taskId: 'bulk-1',
        title: 'A',
        summary: 's',
        status: TaskEventStatus.succeeded,
      );
      final e2 = TaskEvent(
        taskId: 'bulk-2',
        title: 'B',
        summary: 's',
        status: TaskEventStatus.failed,
      );
      bus.publish(e1);
      bus.publish(e2);
      await Future<void>.delayed(Duration.zero);
      final snapshot = Map<String, TaskEvent>.from(bus.latestSnapshot);
      bus.clearAll();
      await Future<void>.delayed(Duration.zero);
      expect(bus.latestSnapshot, isEmpty);

      final eventsSeen = <String>[];
      var snapshotChanges = 0;
      final eventSub = bus.stream.listen((e) => eventsSeen.add(e.taskId));
      final snapSub = bus.snapshotChanges.listen((_) => snapshotChanges++);

      bus.restoreAll(snapshot);
      await Future<void>.delayed(Duration.zero);

      expect(bus.latestFor('bulk-1')?.title, 'A');
      expect(bus.latestFor('bulk-2')?.title, 'B');
      // Bulk restore must fire snapshotChanges exactly once (single rebuild)
      expect(snapshotChanges, 1);
      // And must NOT fire stream — no double-OS-notification
      expect(eventsSeen, isEmpty);

      await eventSub.cancel();
      await snapSub.cancel();
    });

    test('restoreAll preserves newer arrivals (per-entry race protection)', () async {
      final bus = TaskEventBus.instance;
      bus.clearAll();
      final original = TaskEvent(
        taskId: 'race-2',
        title: 'Old',
        summary: 's',
        status: TaskEventStatus.succeeded,
      );
      bus.publish(original);
      await Future<void>.delayed(Duration.zero);
      final snapshot = Map<String, TaskEvent>.from(bus.latestSnapshot);
      bus.clearAll();
      // Newer event arrives in undo window with same taskId.
      bus.publish(TaskEvent(
        taskId: 'race-2',
        title: 'New',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      await Future<void>.delayed(Duration.zero);

      bus.restoreAll(snapshot);

      // Newer entry survives, restoreAll does not clobber.
      expect(bus.latestFor('race-2')?.title, 'New');
    });

    test('restoreAll with empty map is a no-op', () async {
      final bus = TaskEventBus.instance;
      bus.clearAll();
      var snapshotChanges = 0;
      final snapSub = bus.snapshotChanges.listen((_) => snapshotChanges++);

      bus.restoreAll(<String, TaskEvent>{});
      await Future<void>.delayed(Duration.zero);

      expect(snapshotChanges, 0);
      await snapSub.cancel();
    });

    test('restore is a no-op when a newer event arrived during the undo window', () async {
      final bus = TaskEventBus.instance;
      bus.clearAll();
      final original = TaskEvent(
        taskId: 'race-1',
        title: 'Old',
        summary: 's',
        status: TaskEventStatus.succeeded,
      );
      bus.publish(original);
      await Future<void>.delayed(Duration.zero);
      bus.remove('race-1');
      // Newer event with same taskId arrives before user hits undo.
      bus.publish(TaskEvent(
        taskId: 'race-1',
        title: 'New',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(bus.latestFor('race-1')?.title, 'New');

      bus.restore(original);

      // Newer event wins — restore does not clobber it.
      expect(bus.latestFor('race-1')?.title, 'New');
    });

    test('TaskEvent defaults occurredAt to now', () {
      final before = DateTime.now();
      final event = TaskEvent(
        taskId: 't',
        title: 't',
        summary: 's',
        status: TaskEventStatus.running,
      );
      final after = DateTime.now();
      expect(
        event.occurredAt.isBefore(before),
        isFalse,
      );
      expect(
        event.occurredAt.isAfter(after),
        isFalse,
      );
    });

    test('TaskEvent.notify defaults to true', () {
      final event = TaskEvent(
        taskId: 't',
        title: 't',
        summary: 's',
        status: TaskEventStatus.succeeded,
      );
      expect(event.notify, isTrue);
    });

    test('TaskEvent.notify=false survives round-trip through publish', () async {
      final bus = TaskEventBus.instance;
      bus.clearAll();
      bus.publish(TaskEvent(
        taskId: 'silent-1',
        title: 't',
        summary: 's',
        status: TaskEventStatus.succeeded,
        notify: false,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(bus.latestFor('silent-1')?.notify, isFalse);
    });
  });
}
