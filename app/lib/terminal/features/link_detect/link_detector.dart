/// Link detection for terminal output.
///
/// Scans a line of terminal text and returns a list of [DetectedLink]s that
/// can be rendered as tappable spans.  No widgets are defined here — this is
/// a pure-Dart engine meant to be used by the terminal renderer.
library;

/// The kind of link detected in terminal text.
enum LinkType {
  /// An `http://` or `https://` URL.
  url,

  /// A local file-system path such as `/home/user/file.txt` or `./src/main.rs`.
  filePath,

  /// A file path with a line (and optional column) reference: `src/main.rs:42`
  /// or `src/main.rs:42:5`.
  fileWithLocation,
}

/// A detected link inside a line of terminal text.
class DetectedLink {
  /// The raw text that matched (the href).
  final String href;

  /// Start offset (in Unicode code points) within the source line.
  final int start;

  /// End offset (exclusive).
  final int end;

  final LinkType type;

  /// For [LinkType.fileWithLocation]: the line number within the file.
  final int? line;

  /// For [LinkType.fileWithLocation]: the column within the file.
  final int? column;

  const DetectedLink({
    required this.href,
    required this.start,
    required this.end,
    required this.type,
    this.line,
    this.column,
  });

  String get displayText => href;
}

/// Detects links in a single line of plain terminal text (ANSI stripped).
///
/// Returns links in the order they appear in [text].  Overlapping matches are
/// resolved by keeping the longest one.
class LinkDetector {
  // ── Patterns ──────────────────────────────────────────────────────────────

  static final RegExp _urlPattern = RegExp(
    r"""https?://[^\s\]\[()<>"']+""",
    caseSensitive: false,
  );

  // file.rs:42  OR  file.rs:42:5
  static final RegExp _fileLocPattern = RegExp(
    r'(?<![/\w])(?<path>(?:\.{1,2}/|/)?[\w./\-]+\.\w{1,10})'
    r':(?<line>\d+)(?::(?<col>\d+))?',
  );

  // Absolute paths starting with / or relative ./
  static final RegExp _filePathPattern = RegExp(
    r"""(?<![/\w])((?:\.{1,2}/|/)[^\s\]\[()<>"']{2,})""",
  );

  // ── Public API ────────────────────────────────────────────────────────────

  /// Scans [text] and returns all detected links, sorted by start offset.
  static List<DetectedLink> detect(String text) {
    final links = <DetectedLink>[];

    // 1. URLs (highest priority)
    for (final m in _urlPattern.allMatches(text)) {
      links.add(DetectedLink(
        href: m.group(0)!,
        start: m.start,
        end: m.end,
        type: LinkType.url,
      ));
    }

    // 2. File + location  (before plain paths so the longer match wins)
    for (final m in _fileLocPattern.allMatches(text)) {
      if (_overlaps(links, m.start, m.end)) continue;
      links.add(DetectedLink(
        href: m.namedGroup('path')!,
        start: m.start,
        end: m.end,
        type: LinkType.fileWithLocation,
        line: int.tryParse(m.namedGroup('line') ?? ''),
        column: int.tryParse(m.namedGroup('col') ?? ''),
      ));
    }

    // 3. Bare file paths
    for (final m in _filePathPattern.allMatches(text)) {
      if (_overlaps(links, m.start, m.end)) continue;
      links.add(DetectedLink(
        href: m.group(1)!,
        start: m.start,
        end: m.end,
        type: LinkType.filePath,
      ));
    }

    links.sort((a, b) => a.start.compareTo(b.start));
    return links;
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  static bool _overlaps(List<DetectedLink> existing, int start, int end) {
    for (final l in existing) {
      if (start < l.end && end > l.start) return true;
    }
    return false;
  }
}
