/// Unit tests for [taskSourceOf] / [TaskSource] (v0.79.35).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:termex/mobile/task_event_bus.dart';
import 'package:termex/mobile/task_source.dart';

TaskEvent _event(String taskId) => TaskEvent(
      taskId: taskId,
      title: 't',
      summary: 's',
      status: TaskEventStatus.succeeded,
    );

void main() {
  group('taskSourceOf', () {
    test('"sftp-…" prefix → TaskSource.sftp', () {
      expect(taskSourceOf(_event('sftp-12345')), TaskSource.sftp);
      expect(taskSourceOf(_event('sftp-')), TaskSource.sftp);
    });

    test('"ai-…" prefix → TaskSource.ai', () {
      expect(taskSourceOf(_event('ai-conv-123-msg-456')), TaskSource.ai);
      expect(taskSourceOf(_event('ai-')), TaskSource.ai);
    });

    test('unknown prefix → TaskSource.other', () {
      expect(taskSourceOf(_event('demo-test')), TaskSource.other);
      expect(taskSourceOf(_event('cmd-xyz')), TaskSource.other);
      expect(taskSourceOf(_event('')), TaskSource.other);
    });

    test('partial match (no dash) → TaskSource.other', () {
      // "sftpsome" must NOT bucket as sftp — we require the literal "sftp-".
      expect(taskSourceOf(_event('sftpsomeid')), TaskSource.other);
      expect(taskSourceOf(_event('aisuggestion')), TaskSource.other);
    });
  });

  group('TaskSource id round-trip', () {
    test('id getters are stable', () {
      expect(TaskSource.sftp.id, 'sftp');
      expect(TaskSource.ai.id, 'ai');
      expect(TaskSource.other.id, 'other');
    });

    test('parse() resolves ids back', () {
      expect(TaskSourceX.parse('sftp'), TaskSource.sftp);
      expect(TaskSourceX.parse('ai'), TaskSource.ai);
      expect(TaskSourceX.parse('other'), TaskSource.other);
    });

    test('parse() returns null for unknown id', () {
      expect(TaskSourceX.parse('unknown'), isNull);
      expect(TaskSourceX.parse(''), isNull);
    });
  });
}
