/// Terminal search state controller (Riverpod / ChangeNotifier).
///
/// Owns the current query, options, and result, and exposes methods the
/// search overlay widget calls.  The terminal view watches [SearchController]
/// to know which rows to highlight.
library;

import 'package:flutter/foundation.dart';
import 'search_engine.dart';

export 'search_engine.dart';

/// ChangeNotifier that holds the terminal search state.
///
/// Callers must call [search] whenever the terminal buffer changes or the
/// query changes, passing the current list of screen lines.
class SearchController extends ChangeNotifier {
  String _query = '';
  SearchOptions _options = const SearchOptions();
  SearchResult _result = const SearchResult(matches: []);
  bool _isOpen = false;

  String get query => _query;
  SearchOptions get options => _options;
  SearchResult get result => _result;
  bool get isOpen => _isOpen;

  bool get hasMatches => _result.hasMatches;
  int get currentIndex => _result.currentIndex;
  int get matchCount => _result.count;

  // ── Visibility ────────────────────────────────────────────────────────────

  void open() {
    if (!_isOpen) {
      _isOpen = true;
      notifyListeners();
    }
  }

  void close() {
    if (_isOpen) {
      _isOpen = false;
      _query = '';
      _result = const SearchResult(matches: []);
      notifyListeners();
    }
  }

  // ── Query / options ───────────────────────────────────────────────────────

  void setQuery(String query, List<String> lines) {
    _query = query;
    _runSearch(lines);
  }

  void setOptions(SearchOptions options, List<String> lines) {
    _options = options;
    _runSearch(lines);
  }

  void toggleCaseSensitive(List<String> lines) {
    _options = _options.copyWith(caseSensitive: !_options.caseSensitive);
    _runSearch(lines);
  }

  void toggleWholeWord(List<String> lines) {
    _options = _options.copyWith(wholeWord: !_options.wholeWord);
    _runSearch(lines);
  }

  void toggleRegex(List<String> lines) {
    _options = _options.copyWith(useRegex: !_options.useRegex);
    _runSearch(lines);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void goNext() {
    _result = _result.next();
    notifyListeners();
  }

  void goPrevious() {
    _result = _result.previous();
    notifyListeners();
  }

  // ── Buffer refresh ────────────────────────────────────────────────────────

  /// Re-run the search against an updated buffer (e.g. after new output).
  void refreshBuffer(List<String> lines) {
    _runSearch(lines);
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _runSearch(List<String> lines) {
    _result = SearchEngine.search(lines, _query, options: _options);
    notifyListeners();
  }
}
