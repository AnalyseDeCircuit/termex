import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/task/artifact/parser/diff_parser.dart';

const _sampleDiff = '''
diff --git a/src/foo.rs b/src/foo.rs
--- a/src/foo.rs
+++ b/src/foo.rs
@@ -10,3 +10,4 @@
 unchanged line
-removed line
+added line one
+added line two
diff --git a/src/bar.rs b/src/bar.rs
--- a/src/bar.rs
+++ b/src/bar.rs
@@ -1,2 +1,1 @@
 keep me
-drop me
''';

void main() {
  group('DiffParser', () {
    test('empty input yields empty diff', () {
      final d = DiffParser.parse('');
      expect(d.hunks, isEmpty);
      expect(d.filesChanged, 0);
      expect(d.totalAdditions, 0);
      expect(d.totalDeletions, 0);
    });

    test('parses multi-file diff and counts add/del per hunk', () {
      final d = DiffParser.parse(_sampleDiff);
      expect(d.filesChanged, 2);
      expect(d.totalAdditions, 2);
      expect(d.totalDeletions, 2);

      final foo = d.hunks.firstWhere((h) => h.filePath.endsWith('foo.rs'));
      expect(foo.additions, 2);
      expect(foo.deletions, 1);

      final bar = d.hunks.firstWhere((h) => h.filePath.endsWith('bar.rs'));
      expect(bar.additions, 0);
      expect(bar.deletions, 1);
    });

    test('strips a/ and b/ prefixes', () {
      final d = DiffParser.parse(_sampleDiff);
      expect(d.hunks.first.filePath, 'src/foo.rs');
    });

    test('classifies add / del / context lines correctly', () {
      final d = DiffParser.parse(_sampleDiff);
      final lines = d.hunks.first.lines;
      final adds = lines.where((l) => l.kind == DiffLineKind.add).toList();
      final dels = lines.where((l) => l.kind == DiffLineKind.del).toList();
      final ctxs = lines.where((l) => l.kind == DiffLineKind.context).toList();
      expect(adds.length, 2);
      expect(dels.length, 1);
      // 1 ctx in body + a hunk-header is a separate kind so excluded
      expect(ctxs.length, 1);
      expect(dels.first.content, 'removed line');
      expect(adds.first.content, 'added line one');
    });

    test('hunk header drives oldNum / newNum cursors', () {
      final d = DiffParser.parse(_sampleDiff);
      final lines = d.hunks.first.lines;
      final ctxs = lines.where((l) => l.kind == DiffLineKind.context).toList();
      expect(ctxs.first.oldNum, 10);
      expect(ctxs.first.newNum, 10);
      final adds = lines.where((l) => l.kind == DiffLineKind.add).toList();
      // newCursor advances after the first add, so the second add's
      // newNum is one greater.
      expect(adds[1].newNum, (adds[0].newNum ?? 0) + 1);
    });

    test('garbage input degrades to context-only single file', () {
      final d = DiffParser.parse('hello\nworld');
      // No file header → 0 files, no hunks emitted.
      expect(d.hunks, isEmpty);
    });

    test('parses git-style header with file paths having slashes', () {
      const diff = '''
diff --git a/deeply/nested/path.rs b/deeply/nested/path.rs
--- a/deeply/nested/path.rs
+++ b/deeply/nested/path.rs
@@ -1 +1 @@
-old
+new
''';
      final d = DiffParser.parse(diff);
      expect(d.hunks.single.filePath, 'deeply/nested/path.rs');
    });
  });
}
