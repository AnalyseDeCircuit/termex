/// Unit tests for [splitHighlight] (v0.79.42).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:termex/mobile/text_highlight.dart';

void main() {
  group('splitHighlight — degenerate inputs', () {
    test('empty needle returns single non-match segment', () {
      final out = splitHighlight('Uploaded foo.tar.gz', '');
      expect(out.length, 1);
      expect(out.first.text, 'Uploaded foo.tar.gz');
      expect(out.first.isMatch, isFalse);
    });

    test('empty source returns single empty non-match segment', () {
      final out = splitHighlight('', 'foo');
      expect(out.length, 1);
      expect(out.first.text, '');
      expect(out.first.isMatch, isFalse);
    });

    test('no match returns single non-match segment', () {
      final out = splitHighlight('Uploaded foo.tar.gz', 'xyz');
      expect(out.length, 1);
      expect(out.first.text, 'Uploaded foo.tar.gz');
      expect(out.first.isMatch, isFalse);
    });
  });

  group('splitHighlight — single match positions', () {
    test('match at start', () {
      expect(
        splitHighlight('foo.tar.gz', 'foo'),
        const [
          HighlightSegment('foo', isMatch: true),
          HighlightSegment('.tar.gz', isMatch: false),
        ],
      );
    });

    test('match in middle', () {
      expect(
        splitHighlight('Uploaded foo.tar.gz', 'foo'),
        const [
          HighlightSegment('Uploaded ', isMatch: false),
          HighlightSegment('foo', isMatch: true),
          HighlightSegment('.tar.gz', isMatch: false),
        ],
      );
    });

    test('match at end', () {
      expect(
        splitHighlight('Uploaded README.md', '.md'),
        const [
          HighlightSegment('Uploaded README', isMatch: false),
          HighlightSegment('.md', isMatch: true),
        ],
      );
    });

    test('full-string match', () {
      expect(
        splitHighlight('foo', 'foo'),
        const [HighlightSegment('foo', isMatch: true)],
      );
    });
  });

  group('splitHighlight — multiple matches', () {
    test('two non-overlapping matches', () {
      expect(
        splitHighlight('foo bar foo baz', 'foo'),
        const [
          HighlightSegment('foo', isMatch: true),
          HighlightSegment(' bar ', isMatch: false),
          HighlightSegment('foo', isMatch: true),
          HighlightSegment(' baz', isMatch: false),
        ],
      );
    });

    test('adjacent matches (no gap)', () {
      expect(
        splitHighlight('aaaa', 'aa'),
        const [
          HighlightSegment('aa', isMatch: true),
          HighlightSegment('aa', isMatch: true),
        ],
      );
    });
  });

  group('splitHighlight — case insensitivity', () {
    test('lowercase needle matches uppercase source', () {
      // Needle is pre-lowercased per contract; haystack lowercased inline.
      expect(
        splitHighlight('Uploaded FOO.TAR.GZ', 'foo'),
        const [
          HighlightSegment('Uploaded ', isMatch: false),
          HighlightSegment('FOO', isMatch: true),
          HighlightSegment('.TAR.GZ', isMatch: false),
        ],
      );
    });

    test('preserves original casing in match segment', () {
      // The matched substring slice comes from the original source,
      // not the lowercased haystack — important for rendering.
      final out = splitHighlight('Termex', 'term');
      expect(out.first.isMatch, isTrue);
      expect(out.first.text, 'Term');
    });
  });

  group('splitHighlightAll — multi-needle (v0.79.46)', () {
    test('two distinct needles both highlight', () {
      expect(
        splitHighlightAll('Uploaded foo.tar.gz', ['foo', 'gz']),
        const [
          HighlightSegment('Uploaded ', isMatch: false),
          HighlightSegment('foo', isMatch: true),
          HighlightSegment('.tar.', isMatch: false),
          HighlightSegment('gz', isMatch: true),
        ],
      );
    });

    test('one needle matches, one does not — still highlights the hit', () {
      expect(
        splitHighlightAll('Uploaded foo.tar.gz', ['foo', 'xyz']),
        const [
          HighlightSegment('Uploaded ', isMatch: false),
          HighlightSegment('foo', isMatch: true),
          HighlightSegment('.tar.gz', isMatch: false),
        ],
      );
    });

    test('no needle matches → single non-match segment', () {
      expect(
        splitHighlightAll('Uploaded foo.tar.gz', ['abc', 'xyz']),
        const [HighlightSegment('Uploaded foo.tar.gz', isMatch: false)],
      );
    });

    test('empty needles list → single non-match segment', () {
      expect(
        splitHighlightAll('Uploaded foo', const []),
        const [HighlightSegment('Uploaded foo', isMatch: false)],
      );
    });

    test('empty needle strings are filtered out', () {
      expect(
        splitHighlightAll('foo', ['', 'foo', '']),
        const [HighlightSegment('foo', isMatch: true)],
      );
    });

    test('overlapping needles: earliest-then-shortest deterministic', () {
      // "foo" at pos 0, "foobar" at pos 0. Same start → shorter wins.
      // Cursor advances by "foo" (3), then "bar" at pos 3 matches.
      expect(
        splitHighlightAll('foobar baz', ['foobar', 'foo', 'bar']),
        const [
          HighlightSegment('foo', isMatch: true),
          HighlightSegment('bar', isMatch: true),
          HighlightSegment(' baz', isMatch: false),
        ],
      );
    });

    test('case-insensitive across all needles', () {
      expect(
        splitHighlightAll('Uploaded FOO.tar.GZ', ['foo', 'gz']),
        const [
          HighlightSegment('Uploaded ', isMatch: false),
          HighlightSegment('FOO', isMatch: true),
          HighlightSegment('.tar.', isMatch: false),
          HighlightSegment('GZ', isMatch: true),
        ],
      );
    });

    test('two matches of same needle highlighted twice', () {
      expect(
        splitHighlightAll('foo bar foo', ['foo']),
        const [
          HighlightSegment('foo', isMatch: true),
          HighlightSegment(' bar ', isMatch: false),
          HighlightSegment('foo', isMatch: true),
        ],
      );
    });
  });
}
