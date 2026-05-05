import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/ai/features/ai_suggestion_source.dart';

void main() {
  group('AiSuggestionSource', () {
    late AiSuggestionSource source;

    setUp(() => source = AiSuggestionSource());

    test('empty prefix returns up to 5 recent commands', () {
      source.onAiMessage(['ls -la', 'pwd', 'cd /tmp', 'cat file.txt', 'echo hi', 'grep foo']);
      expect(source.suggest(''), hasLength(5));
    });

    test('prefix filtering returns matching commands', () {
      source.onAiMessage(['ls -la', 'ls /etc', 'pwd', 'cat file.txt']);
      final results = source.suggest('ls');
      expect(results, hasLength(2));
      expect(results.every((c) => c.startsWith('ls')), isTrue);
    });

    test('most recent commands appear first', () {
      source.onAiMessage(['old-cmd']);
      source.onAiMessage(['new-cmd']);
      final results = source.suggest('');
      expect(results.first, 'new-cmd');
    });

    test('duplicates are deduplicated', () {
      source.onAiMessage(['ls -la']);
      source.onAiMessage(['ls -la']); // same command
      expect(source.suggest('ls'), hasLength(1));
    });

    test('clear removes all commands', () {
      source.onAiMessage(['ls -la', 'pwd']);
      source.clear();
      expect(source.suggest(''), isEmpty);
    });

    test('respects max 50 commands', () {
      source.onAiMessage(List.generate(60, (i) => 'cmd-$i'));
      expect(source.suggest('').length, lessThanOrEqualTo(5));
    });
  });
}
