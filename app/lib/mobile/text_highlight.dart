/// Substring highlighter for search-result rendering (v0.79.42).
///
/// Splits a source string into alternating `match` / `non-match` segments
/// against a lowercase needle. Used by [MobileTaskHistoryPage]'s task
/// rows to make search hits visually pop without coupling the row widget
/// to the parent's query state model.
///
/// Empty needle / no matches → single non-match segment containing the
/// full source, so callers can always wrap the result in `RichText`
/// without a "what if empty" branch.
library;

class HighlightSegment {
  final String text;
  final bool isMatch;
  const HighlightSegment(this.text, {required this.isMatch});

  @override
  bool operator ==(Object other) =>
      other is HighlightSegment &&
      other.text == text &&
      other.isMatch == isMatch;

  @override
  int get hashCode => Object.hash(text, isMatch);

  @override
  String toString() => '${isMatch ? '!' : '.'}"$text"';
}

/// Case-insensitive substring scan against a single [needle]. Thin
/// wrapper over [splitHighlightAll] for callers that have one keyword.
/// Kept for source compatibility with v0.79.42 call sites.
List<HighlightSegment> splitHighlight(String source, String needle) =>
    splitHighlightAll(source, needle.isEmpty ? const [] : [needle]);

/// v0.79.46: multi-needle variant. Highlights every occurrence of every
/// needle, returning a flat list of alternating match / non-match
/// segments. When needles overlap on a position, the *first* matching
/// needle wins and the cursor advances past its length — later needles
/// at the same position are not re-counted (deterministic + avoids
/// duplicate highlight spans).
///
/// [needles] are expected pre-lowercased (the history page caches the
/// trimmed/lowercased tokens in `_searchQueryTokens`). Empty needles
/// are filtered out so callers can pass raw `split(' ')` output without
/// guarding against trailing whitespace.
///
/// Returns a list guaranteed non-empty: at minimum
/// `[HighlightSegment(source, isMatch: false)]`.
List<HighlightSegment> splitHighlightAll(
  String source,
  Iterable<String> needles,
) {
  final active = [for (final n in needles) if (n.isNotEmpty) n];
  if (active.isEmpty || source.isEmpty) {
    return [HighlightSegment(source, isMatch: false)];
  }
  final haystack = source.toLowerCase();
  final segments = <HighlightSegment>[];
  var cursor = 0;
  while (cursor < source.length) {
    // Find the earliest match across all needles starting from cursor.
    // Tie-break: shorter needle wins (deterministic, lets distinct
    // shorter keywords highlight separately rather than getting eaten
    // by a longer one).
    var bestHit = -1;
    var bestLen = 0;
    for (final n in active) {
      final hit = haystack.indexOf(n, cursor);
      if (hit < 0) continue;
      if (bestHit < 0 ||
          hit < bestHit ||
          (hit == bestHit && n.length < bestLen)) {
        bestHit = hit;
        bestLen = n.length;
      }
    }
    if (bestHit < 0) {
      segments.add(HighlightSegment(source.substring(cursor), isMatch: false));
      break;
    }
    if (bestHit > cursor) {
      segments.add(HighlightSegment(
        source.substring(cursor, bestHit),
        isMatch: false,
      ));
    }
    segments.add(HighlightSegment(
      source.substring(bestHit, bestHit + bestLen),
      isMatch: true,
    ));
    cursor = bestHit + bestLen;
  }
  if (segments.isEmpty) {
    return [HighlightSegment(source, isMatch: false)];
  }
  return segments;
}
