import 'package:flutter_test/flutter_test.dart';
import 'package:termex/terminal/features/keyword_highlight/highlight_engine.dart';

void main() {
  group('HighlightEngine', () {
    late HighlightEngine engine;

    setUp(() => engine = HighlightEngine.withDefaults());

    test('highlights ERROR keyword', () {
      final spans = engine.highlight('ERROR: something failed');
      expect(spans, isNotEmpty);
      expect(spans.first.start, 0);
      expect(spans.first.end, 5);
    });

    test('highlights WARNING keyword', () {
      final spans = engine.highlight('WARNING: disk almost full');
      expect(spans.any((s) => s.start == 0), isTrue);
    });

    test('highlights success', () {
      final spans = engine.highlight('✓ All tests passed: 42 ok');
      expect(spans.any((s) => s.color == HighlightColor.green), isTrue);
    });

    test('returns empty for unmatched line', () {
      final spans = engine.highlight('hello world foo bar');
      expect(spans, isEmpty);
    });

    test('does not overlap spans', () {
      final spans = engine.highlight('ERROR WARNING something');
      for (int i = 0; i < spans.length - 1; i++) {
        expect(spans[i].end, lessThanOrEqualTo(spans[i + 1].start));
      }
    });

    test('custom rule matches', () {
      final custom = HighlightEngine(rules: [
        HighlightRule.fromString('CUSTOM', color: HighlightColor.blue),
      ]);
      final spans = custom.highlight('line with CUSTOM keyword');
      expect(spans.any((s) => s.color == HighlightColor.blue), isTrue);
    });
  });
}
