/// Terminal search engine — scans scrollback + main buffer for matches.
///
/// This is a pure-Dart engine with no widget dependencies.  The terminal
/// renderer calls [SearchEngine.search] and uses [SearchResult] to overlay
/// highlight rectangles on the matching cells.
library;

/// A single search match within a terminal buffer.
class SearchMatch {
  /// Zero-based row index in the combined buffer (scrollback + main screen).
  final int row;

  /// Column offset of the match start.
  final int startCol;

  /// Column offset exclusive end.
  final int endCol;

  const SearchMatch({
    required this.row,
    required this.startCol,
    required this.endCol,
  });
}

/// The result of a full-buffer search.
class SearchResult {
  final List<SearchMatch> matches;
  final int currentIndex;

  const SearchResult({required this.matches, this.currentIndex = 0});

  bool get hasMatches => matches.isNotEmpty;
  int get count => matches.length;

  SearchMatch? get current =>
      matches.isEmpty ? null : matches[currentIndex];

  SearchResult withIndex(int index) => SearchResult(
        matches: matches,
        currentIndex: index.clamp(0, matches.isEmpty ? 0 : matches.length - 1),
      );

  SearchResult next() {
    if (matches.isEmpty) return this;
    return withIndex((currentIndex + 1) % matches.length);
  }

  SearchResult previous() {
    if (matches.isEmpty) return this;
    return withIndex((currentIndex - 1 + matches.length) % matches.length);
  }
}

/// Options for a search operation.
class SearchOptions {
  final bool caseSensitive;
  final bool wholeWord;
  final bool useRegex;

  const SearchOptions({
    this.caseSensitive = false,
    this.wholeWord = false,
    this.useRegex = false,
  });

  SearchOptions copyWith({
    bool? caseSensitive,
    bool? wholeWord,
    bool? useRegex,
  }) =>
      SearchOptions(
        caseSensitive: caseSensitive ?? this.caseSensitive,
        wholeWord: wholeWord ?? this.wholeWord,
        useRegex: useRegex ?? this.useRegex,
      );
}

/// Searches a list of plain text lines (the terminal's scrollback + screen).
///
/// Returns all [SearchMatch]es.  On an empty or invalid query returns an
/// empty [SearchResult].
class SearchEngine {
  static SearchResult search(
    List<String> lines,
    String query, {
    SearchOptions options = const SearchOptions(),
  }) {
    if (query.isEmpty) return const SearchResult(matches: []);

    RegExp? pattern;
    try {
      String regexSource = options.useRegex ? query : RegExp.escape(query);
      if (options.wholeWord) {
        regexSource = r'\b' + regexSource + r'\b';
      }
      pattern = RegExp(
        regexSource,
        caseSensitive: options.caseSensitive,
        multiLine: false,
      );
    } catch (_) {
      // Invalid regex — return empty.
      return const SearchResult(matches: []);
    }

    final matches = <SearchMatch>[];
    for (int row = 0; row < lines.length; row++) {
      for (final m in pattern.allMatches(lines[row])) {
        matches.add(SearchMatch(
          row: row,
          startCol: m.start,
          endCol: m.end,
        ));
      }
    }

    return SearchResult(matches: matches);
  }
}
