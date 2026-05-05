/// Terminal autocomplete engine.
///
/// Merges suggestions from multiple [SuggestionSource]s, deduplicates,
/// and ranks them. The engine is query-driven: call [query] with the current
/// input line and it returns a ranked list of [AutocompleteSuggestion]s.
library;

import 'package:flutter/foundation.dart';

import 'suggestion_source.dart';
export 'suggestion_source.dart';

/// Coordinates multiple [SuggestionSource]s into a ranked suggestion list.
class AutocompleteEngine {
  final List<SuggestionSource> _sources;

  /// Optional AI-backed source — registered separately so callers can feed it
  /// asynchronously after an AI response arrives.
  AiBackedSuggestionSource? _aiSource;

  AutocompleteEngine({List<SuggestionSource>? sources})
      : _sources = sources ?? [BuiltinCommandSource()];

  /// Attach an [AiBackedSuggestionSource] so the engine can use it for
  /// suggestions when other sources come up empty.
  void registerAiSource(AiBackedSuggestionSource source) {
    _aiSource = source;
    if (!_sources.contains(source)) _sources.add(source);
  }

  /// Returns up to [maxResults] ranked suggestions for [inputLine].
  ///
  /// The engine extracts the last token as the completion prefix.
  List<AutocompleteSuggestion> query(
    String inputLine, {
    int maxResults = 10,
  }) {
    final prefix = _lastToken(inputLine);
    if (prefix.isEmpty) return [];

    final seen = <String>{};
    final all = <AutocompleteSuggestion>[];

    for (final source in _sources) {
      for (final s in source.suggest(prefix)) {
        if (seen.add(s.value)) {
          all.add(s);
        }
      }
    }

    all.sort((a, b) {
      final scoreDiff = b.score - a.score;
      if (scoreDiff != 0) return scoreDiff;
      return a.value.compareTo(b.value);
    });

    return all.take(maxResults).toList();
  }

  /// Adds a source at runtime (e.g. path source or flag source).
  void addSource(SuggestionSource source) {
    _sources.add(source);
  }

  static String _lastToken(String line) {
    if (line.isEmpty) return '';
    if (line.endsWith(' ')) return '';
    final spaceIdx = line.lastIndexOf(' ');
    if (spaceIdx == -1) return line;
    return line.substring(spaceIdx + 1);
  }
}

/// ChangeNotifier that holds autocomplete state for a terminal session.
class AutocompleteController extends ChangeNotifier {
  final AutocompleteEngine _engine;

  List<AutocompleteSuggestion> _suggestions = [];
  int _selectedIndex = 0;
  bool _isOpen = false;

  AutocompleteController({AutocompleteEngine? engine})
      : _engine = engine ?? AutocompleteEngine();

  List<AutocompleteSuggestion> get suggestions => _suggestions;
  int get selectedIndex => _selectedIndex;
  bool get isOpen => _isOpen && _suggestions.isNotEmpty;

  AutocompleteSuggestion? get selected =>
      _suggestions.isEmpty ? null : _suggestions[_selectedIndex];

  /// Update suggestions for the current [inputLine].
  void onInputChanged(String inputLine) {
    final next = _engine.query(inputLine);
    _suggestions = next;
    _selectedIndex = 0;
    _isOpen = next.isNotEmpty;
    notifyListeners();
  }

  void close() {
    if (_isOpen) {
      _isOpen = false;
      _suggestions = [];
      notifyListeners();
    }
  }

  /// Move selection down (Tab / ↓).
  void selectNext() {
    if (_suggestions.isEmpty) return;
    _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
    notifyListeners();
  }

  /// Move selection up (Shift+Tab / ↑).
  void selectPrevious() {
    if (_suggestions.isEmpty) return;
    _selectedIndex =
        (_selectedIndex - 1 + _suggestions.length) % _suggestions.length;
    notifyListeners();
  }

  /// Returns the suffix to insert for the accepted suggestion and closes.
  String? acceptSelected(String inputLine) {
    final s = selected;
    if (s == null) return null;
    close();
    final prefix = _lastToken(inputLine);
    if (s.value.startsWith(prefix)) return s.value.substring(prefix.length);
    return s.value;
  }

  static String _lastToken(String line) {
    final trimmed = line.trimRight();
    if (trimmed.isEmpty) return '';
    final idx = trimmed.lastIndexOf(' ');
    return idx == -1 ? trimmed : trimmed.substring(idx + 1);
  }
}
