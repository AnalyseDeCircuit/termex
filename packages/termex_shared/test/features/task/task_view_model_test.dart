import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/task/model/task_view_model.dart';

void main() {
  group('TaskStatus.fromWire / wireName', () {
    test('roundtrips all variants', () {
      for (final s in TaskStatus.values) {
        expect(TaskStatus.fromWire(s.wireName), equals(s),
            reason: '${s.wireName} must roundtrip');
      }
    });

    test('unknown defaults to pending', () {
      expect(TaskStatus.fromWire('xyz'), TaskStatus.pending);
    });

    test('isTerminal classification', () {
      expect(TaskStatus.succeeded.isTerminal, isTrue);
      expect(TaskStatus.failed.isTerminal, isTrue);
      expect(TaskStatus.cancelled.isTerminal, isTrue);
      expect(TaskStatus.running.isTerminal, isFalse);
      expect(TaskStatus.pending.isTerminal, isFalse);
      expect(TaskStatus.pendingConfirmation.isTerminal, isFalse);
    });
  });

  group('AiCliKind.fromWire / wireName', () {
    test('roundtrips known variants', () {
      for (final k in AiCliKind.values) {
        expect(AiCliKind.fromWire(k.wireName), equals(k));
      }
    });

    test('unknown defaults to generic', () {
      expect(AiCliKind.fromWire('rust'), AiCliKind.generic);
    });
  });

  group('TaskViewModel.elapsedHuman', () {
    final base = DateTime.utc(2026, 5, 23, 10, 0, 0);

    TaskViewModel make(Duration since) {
      return TaskViewModel(
        id: 't', serverId: 's', serverName: 'home-dev',
        prompt: 'p', status: TaskStatus.running,
        aiCliKind: AiCliKind.generic,
        startedAt: base,
        endedAt: base.add(since),
      );
    }

    test('seconds-only', () {
      expect(make(const Duration(seconds: 5)).elapsedHuman, '5s');
    });

    test('minutes + seconds', () {
      expect(make(const Duration(minutes: 2, seconds: 14)).elapsedHuman,
          '2m 14s');
    });

    test('hours + minutes', () {
      expect(make(const Duration(hours: 1, minutes: 3)).elapsedHuman, '1h 3m');
    });
  });

  test('copyWith preserves unset fields and overrides set ones', () {
    final t = TaskViewModel(
      id: 'a', serverId: 's', serverName: 'srv', prompt: 'p',
      status: TaskStatus.running, aiCliKind: AiCliKind.aider,
      startedAt: DateTime.utc(2026, 1, 1),
      totalInputTokens: 100,
    );
    final t2 = t.copyWith(status: TaskStatus.succeeded);
    expect(t2.status, TaskStatus.succeeded);
    expect(t2.id, t.id);
    expect(t2.totalInputTokens, 100);
    expect(t2.aiCliKind, AiCliKind.aider);
  });
}
