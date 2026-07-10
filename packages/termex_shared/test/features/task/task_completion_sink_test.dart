/// Unit tests for [TaskCompletionSink] (v0.79.25).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/task/task_completion_sink.dart';

void main() {
  group('TaskCompletionSink', () {
    tearDown(() => TaskCompletionSink.register(null));

    test('emit is a no-op when no callback is registered', () {
      // Should not throw.
      TaskCompletionSink.emit(const TaskCompletionPayload(
        taskId: 't',
        title: 'title',
        summary: 'sum',
        success: true,
      ));
    });

    test('register installs the callback and emit forwards payload', () {
      TaskCompletionPayload? captured;
      TaskCompletionSink.register((p) => captured = p);

      TaskCompletionSink.emit(const TaskCompletionPayload(
        taskId: 'task-1',
        title: 'Uploaded foo.tar.gz',
        summary: 'Upload completed (12.4 MB)',
        success: true,
      ));

      expect(captured, isNotNull);
      expect(captured!.taskId, 'task-1');
      expect(captured!.title, 'Uploaded foo.tar.gz');
      expect(captured!.summary, 'Upload completed (12.4 MB)');
      expect(captured!.success, isTrue);
    });

    test('register null detaches the previous callback', () {
      var emitted = 0;
      TaskCompletionSink.register((_) => emitted++);
      TaskCompletionSink.emit(const TaskCompletionPayload(
        taskId: 't',
        title: 'T',
        summary: 'S',
        success: false,
      ));
      expect(emitted, 1);

      TaskCompletionSink.register(null);
      TaskCompletionSink.emit(const TaskCompletionPayload(
        taskId: 't2',
        title: 'T2',
        summary: 'S2',
        success: false,
      ));
      expect(emitted, 1);
    });
  });
}
