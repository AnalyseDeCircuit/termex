import 'package:flutter_test/flutter_test.dart';
import 'package:termex/terminal/features/search/search_engine.dart';

void main() {
  group('SearchEngine', () {
    final lines = [
      'Hello World',
      'hello world',
      'foo bar baz',
      'the quick brown fox',
    ];

    test('returns empty result for empty query', () {
      final r = SearchEngine.search(lines, '');
      expect(r.matches, isEmpty);
    });

    test('finds case-insensitive match by default', () {
      final r = SearchEngine.search(lines, 'hello');
      expect(r.count, 2);
    });

    test('finds case-sensitive match', () {
      final r = SearchEngine.search(
        lines,
        'hello',
        options: const SearchOptions(caseSensitive: true),
      );
      expect(r.count, 1);
      expect(r.matches.first.row, 1);
    });

    test('finds whole word match', () {
      final r = SearchEngine.search(
        lines,
        'bar',
        options: const SearchOptions(wholeWord: true),
      );
      expect(r.count, 1);
      expect(r.matches.first.row, 2);
    });

    test('finds regex match', () {
      final r = SearchEngine.search(
        lines,
        r'qu\w+',
        options: const SearchOptions(useRegex: true),
      );
      expect(r.count, 1);
      expect(r.matches.first.startCol, lines[3].indexOf('quick'));
    });

    test('returns empty result for invalid regex', () {
      final r = SearchEngine.search(
        lines,
        r'[invalid',
        options: const SearchOptions(useRegex: true),
      );
      expect(r.matches, isEmpty);
    });

    test('match startCol and endCol are correct', () {
      final r = SearchEngine.search(lines, 'World');
      expect(r.matches.first.startCol, 6);
      expect(r.matches.first.endCol, 11);
    });
  });

  group('SearchResult navigation', () {
    final matches = [
      const SearchMatch(row: 0, startCol: 0, endCol: 3),
      const SearchMatch(row: 1, startCol: 0, endCol: 3),
      const SearchMatch(row: 2, startCol: 0, endCol: 3),
    ];
    final result = SearchResult(matches: matches);

    test('next wraps around', () {
      final last = result.withIndex(2).next();
      expect(last.currentIndex, 0);
    });

    test('previous wraps around', () {
      final first = result.withIndex(0).previous();
      expect(first.currentIndex, 2);
    });
  });
}
