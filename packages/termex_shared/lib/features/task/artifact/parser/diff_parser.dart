/// Minimal unified-diff parser sufficient to drive [DiffViewer].
///
/// Pure Dart, no regex backreferences — handles standard
/// `diff --git a/X b/Y` / `--- a/X` / `+++ b/Y` / `@@ -i,n +j,m @@`
/// hunks. Bad input degrades to a single `raw` line carrying the
/// original text so the UI can still render something.
library;

enum DiffLineKind { context, add, del, hunkHeader, fileHeader }

class DiffLine {
  final DiffLineKind kind;
  final int? oldNum;
  final int? newNum;
  final String content;
  const DiffLine({
    required this.kind,
    this.oldNum,
    this.newNum,
    required this.content,
  });
}

class DiffHunk {
  final String filePath;
  final int additions;
  final int deletions;
  final List<DiffLine> lines;
  const DiffHunk({
    required this.filePath,
    required this.additions,
    required this.deletions,
    required this.lines,
  });
}

class ParsedDiff {
  final List<DiffHunk> hunks;
  final int totalAdditions;
  final int totalDeletions;
  final int filesChanged;
  const ParsedDiff({
    required this.hunks,
    required this.totalAdditions,
    required this.totalDeletions,
    required this.filesChanged,
  });

  factory ParsedDiff.empty() => const ParsedDiff(
        hunks: [],
        totalAdditions: 0,
        totalDeletions: 0,
        filesChanged: 0,
      );
}

class DiffParser {
  /// Parse a unified-diff blob into hunks grouped by file. Lines that
  /// don't fit known prefixes are folded into the current hunk as
  /// `context` so we don't lose anything.
  static ParsedDiff parse(String text) {
    if (text.trim().isEmpty) return ParsedDiff.empty();

    final hunks = <DiffHunk>[];
    String? currentFile;
    List<DiffLine> currentLines = [];
    int hunkAdds = 0;
    int hunkDels = 0;
    int? oldCursor;
    int? newCursor;
    final files = <String>{};
    var totalAdd = 0;
    var totalDel = 0;

    void flushHunk() {
      final file = currentFile;
      if (file == null || currentLines.isEmpty) {
        currentLines = [];
        hunkAdds = 0;
        hunkDels = 0;
        return;
      }
      hunks.add(DiffHunk(
        filePath: file,
        additions: hunkAdds,
        deletions: hunkDels,
        lines: List<DiffLine>.unmodifiable(currentLines),
      ));
      files.add(file);
      totalAdd += hunkAdds;
      totalDel += hunkDels;
      currentLines = [];
      hunkAdds = 0;
      hunkDels = 0;
    }

    for (final raw in text.split('\n')) {
      if (raw.startsWith('diff --git ')) {
        flushHunk();
        currentFile = _extractFileFromGitHeader(raw);
        currentLines.add(DiffLine(kind: DiffLineKind.fileHeader, content: raw));
        continue;
      }
      if (raw.startsWith('--- ') || raw.startsWith('+++ ')) {
        // Use +++ as the authoritative new-side file path.
        if (raw.startsWith('+++ ') && currentFile == null) {
          currentFile = _stripPrefix(raw.substring(4));
        }
        currentLines.add(DiffLine(kind: DiffLineKind.fileHeader, content: raw));
        continue;
      }
      if (raw.startsWith('@@')) {
        final hunkHead = _parseHunkHeader(raw);
        if (hunkHead != null) {
          oldCursor = hunkHead.$1;
          newCursor = hunkHead.$2;
        }
        currentLines.add(DiffLine(kind: DiffLineKind.hunkHeader, content: raw));
        continue;
      }
      if (raw.isEmpty) {
        currentLines.add(const DiffLine(kind: DiffLineKind.context, content: ''));
        oldCursor = oldCursor == null ? null : oldCursor + 1;
        newCursor = newCursor == null ? null : newCursor + 1;
        continue;
      }
      final first = raw[0];
      if (first == '+') {
        hunkAdds++;
        currentLines.add(DiffLine(
          kind: DiffLineKind.add,
          newNum: newCursor,
          content: raw.substring(1),
        ));
        newCursor = newCursor == null ? null : newCursor + 1;
      } else if (first == '-') {
        hunkDels++;
        currentLines.add(DiffLine(
          kind: DiffLineKind.del,
          oldNum: oldCursor,
          content: raw.substring(1),
        ));
        oldCursor = oldCursor == null ? null : oldCursor + 1;
      } else if (first == ' ') {
        currentLines.add(DiffLine(
          kind: DiffLineKind.context,
          oldNum: oldCursor,
          newNum: newCursor,
          content: raw.substring(1),
        ));
        oldCursor = oldCursor == null ? null : oldCursor + 1;
        newCursor = newCursor == null ? null : newCursor + 1;
      } else {
        // Unknown prefix — keep as context so the UI shows something.
        currentLines.add(DiffLine(kind: DiffLineKind.context, content: raw));
      }
    }
    flushHunk();

    return ParsedDiff(
      hunks: List<DiffHunk>.unmodifiable(hunks),
      totalAdditions: totalAdd,
      totalDeletions: totalDel,
      filesChanged: files.length,
    );
  }

  /// `diff --git a/foo/bar.rs b/foo/bar.rs` → `foo/bar.rs`.
  static String? _extractFileFromGitHeader(String line) {
    final parts = line.split(' ');
    if (parts.length < 4) return null;
    return _stripPrefix(parts.last);
  }

  /// Strip `a/` / `b/` prefix common to unified diffs.
  static String _stripPrefix(String s) {
    final t = s.trim();
    if (t.startsWith('a/') || t.startsWith('b/')) return t.substring(2);
    return t;
  }

  /// `@@ -10,4 +12,5 @@` → (10, 12) old/new starting line numbers.
  /// Returns null on malformed headers.
  static (int, int)? _parseHunkHeader(String line) {
    final parts = line.split(' ');
    int? findStart(String spec) {
      final body = spec.substring(1); // drop -/+
      final comma = body.indexOf(',');
      final n = comma < 0 ? body : body.substring(0, comma);
      return int.tryParse(n);
    }

    int? oldStart;
    int? newStart;
    for (final p in parts) {
      if (p.startsWith('-')) oldStart = findStart(p);
      if (p.startsWith('+')) newStart = findStart(p);
    }
    if (oldStart == null || newStart == null) return null;
    return (oldStart, newStart);
  }
}
