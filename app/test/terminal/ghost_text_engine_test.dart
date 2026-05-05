import 'package:flutter_test/flutter_test.dart';
import 'package:termex/terminal/features/ghost_text/ghost_text_engine.dart';

void main() {
  group('GhostTextEngine', () {
    late GhostTextEngine engine;

    setUp(() => engine = GhostTextEngine());

    test('returns null for empty prefix', () {
      engine.recordCommand('git status');
      expect(engine.suggest(''), isNull);
    });

    test('returns null when no history matches prefix', () {
      engine.recordCommand('ls -la');
      expect(engine.suggest('gi'), isNull);
    });

    test('suggests a previously recorded command', () {
      engine.recordCommand('git commit -m "fix"');
      final s = engine.suggest('git');
      expect(s, isNotNull);
      expect(s!.fullCommand, 'git commit -m "fix"');
      expect(s.ghostSuffix, ' commit -m "fix"');
    });

    test('picks the most frequent command', () {
      engine.recordCommand('git status');
      engine.recordCommand('git push');
      engine.recordCommand('git push'); // push x2
      final s = engine.suggest('git');
      expect(s!.fullCommand, 'git push');
    });

    test('returns null when prefix equals full command (no suffix)', () {
      engine.recordCommand('ls');
      final s = engine.suggest('ls');
      // ghostSuffix is empty — overlay should hide
      expect(s?.ghostSuffix, isEmpty);
    });

    test('recordAll seeds multiple commands', () {
      engine.recordAll(['cd /tmp', 'cd /home', 'cat file.txt']);
      expect(engine.suggest('cd'), isNotNull);
      expect(engine.suggest('cat'), isNotNull);
    });

    test('evicts oldest command after maxHistorySize', () {
      for (int i = 0; i < GhostTextEngine.maxHistorySize; i++) {
        engine.recordCommand('cmd$i');
      }
      // Record one more — cmd0 should be evicted.
      engine.recordCommand('last');
      expect(engine.suggest('cmd0'), isNull);
      expect(engine.suggest('last'), isNotNull);
    });

    test('clear removes all history', () {
      engine.recordCommand('docker ps');
      engine.clear();
      expect(engine.suggest('docker'), isNull);
    });
  });

  group('GhostTextEngine.acceptOneWord', () {
    test('returns suffix up to first space', () {
      expect(GhostTextEngine.acceptOneWord('git', ' commit -m'), ' commit');
    });

    test('returns full suffix when no space', () {
      expect(GhostTextEngine.acceptOneWord('gits', 'tatus'), 'tatus');
    });
  });
}
