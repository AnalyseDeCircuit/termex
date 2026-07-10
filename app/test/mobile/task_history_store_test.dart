/// Unit tests for [TaskEvent.toJson/fromJson] and persistence behaviour
/// against an in-memory [TaskHistoryPersistence] fake (v0.79.26).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:termex/mobile/task_event_bus.dart';

class _FakeStore implements TaskHistoryPersistence {
  Map<String, TaskEvent> stored = {};
  int saveCount = 0;

  @override
  Future<Map<String, TaskEvent>> load() async => Map.of(stored);

  @override
  Future<void> save(Map<String, TaskEvent> snapshot) async {
    saveCount++;
    stored = Map.of(snapshot);
  }
}

void main() {
  group('TaskEvent JSON ser/de', () {
    test('round-trips all fields', () {
      final original = TaskEvent(
        taskId: 'sftp-123',
        title: 'Uploaded foo.tar.gz',
        summary: 'Upload completed (12.4 MB)',
        status: TaskEventStatus.succeeded,
        occurredAt: DateTime.utc(2026, 5, 31, 9, 0, 0),
      );
      final json = original.toJson();
      final restored = TaskEvent.fromJson(json);
      expect(restored, isNotNull);
      expect(restored!.taskId, original.taskId);
      expect(restored.title, original.title);
      expect(restored.summary, original.summary);
      expect(restored.status, original.status);
      expect(restored.occurredAt, original.occurredAt);
    });

    test('fromJson returns null on unknown status', () {
      final json = {
        'taskId': 't',
        'title': 't',
        'summary': 's',
        'status': 'fictional',
        'occurredAt': '2026-05-31T09:00:00.000Z',
      };
      expect(TaskEvent.fromJson(json), isNull);
    });

    test('fromJson returns null on missing field', () {
      final json = {
        'taskId': 't',
        'title': 't',
        'summary': 's',
        // status missing
        'occurredAt': '2026-05-31T09:00:00.000Z',
      };
      expect(TaskEvent.fromJson(json), isNull);
    });

    test('fromJson returns null on malformed occurredAt', () {
      final json = {
        'taskId': 't',
        'title': 't',
        'summary': 's',
        'status': 'succeeded',
        'occurredAt': 'not-a-date',
      };
      expect(TaskEvent.fromJson(json), isNull);
    });
  });

  group('TaskEventBus persistence', () {
    test('hydrate loads stored events into latestSnapshot', () async {
      final store = _FakeStore();
      final pre = TaskEvent(
        taskId: 'old-1',
        title: 'Old',
        summary: 'Loaded',
        status: TaskEventStatus.succeeded,
        occurredAt: DateTime.utc(2026, 5, 30),
      );
      store.stored = {'old-1': pre};

      TaskEventBus.instance.attachPersistence(store);
      await TaskEventBus.instance.hydrate();

      final restored = TaskEventBus.instance.latestFor('old-1');
      expect(restored, isNotNull);
      expect(restored!.title, 'Old');
    });

    test('publish triggers debounced save', () async {
      final store = _FakeStore();
      TaskEventBus.instance.attachPersistence(store);

      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'p-1',
        title: 'p',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));
      // Debounced — save shouldn't have fired yet.
      expect(store.saveCount, 0);

      // Wait past the debounce window.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(store.saveCount, greaterThanOrEqualTo(1));
      expect(store.stored.containsKey('p-1'), isTrue);
    });
  });
}
