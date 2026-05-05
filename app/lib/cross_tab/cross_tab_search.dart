/// Cross-Tab scrollback search (v0.48 spec §5.2).
///
/// Queries a registered list of [TabScrollbackProvider]s in parallel and
/// aggregates results by Tab.  UI layer displays a dialog with match counts
/// and jump links.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Abstraction ─────────────────────────────────────────────────────────────

/// Implemented by each terminal Tab's scrollback buffer.
abstract class TabScrollbackProvider {
  String get tabId;
  String get serverName;

  /// Returns the line numbers (0-indexed) that match [query].
  List<CrossTabMatch> search(String query);
}

/// A single search hit inside a Tab's scrollback.
class CrossTabMatch {
  final String tabId;
  final String serverName;
  final int lineNumber;
  final String linePreview;

  const CrossTabMatch({
    required this.tabId,
    required this.serverName,
    required this.lineNumber,
    required this.linePreview,
  });
}

/// Aggregated results for one Tab.
class TabSearchResult {
  final String tabId;
  final String serverName;
  final List<CrossTabMatch> matches;

  const TabSearchResult({
    required this.tabId,
    required this.serverName,
    required this.matches,
  });

  int get count => matches.length;
}

// ─── Controller ──────────────────────────────────────────────────────────────

class CrossTabSearchController {
  CrossTabSearchController._();

  static final CrossTabSearchController instance =
      CrossTabSearchController._();

  final List<TabScrollbackProvider> _providers = [];

  void registerTab(TabScrollbackProvider provider) {
    _providers.removeWhere((p) => p.tabId == provider.tabId);
    _providers.add(provider);
  }

  void unregisterTab(String tabId) {
    _providers.removeWhere((p) => p.tabId == tabId);
  }

  /// Searches all registered Tabs for [query].
  ///
  /// Empty query returns an empty list immediately.
  List<TabSearchResult> search(String query) {
    if (query.isEmpty) return [];
    final results = <TabSearchResult>[];
    for (final p in _providers) {
      final hits = p.search(query);
      if (hits.isNotEmpty) {
        results.add(TabSearchResult(
          tabId: p.tabId,
          serverName: p.serverName,
          matches: hits,
        ));
      }
    }
    return results;
  }

  void clear() => _providers.clear();
}

// ─── Riverpod state ──────────────────────────────────────────────────────────

class CrossTabSearchState {
  final String query;
  final List<TabSearchResult> results;
  final bool isSearching;

  const CrossTabSearchState({
    this.query = '',
    this.results = const [],
    this.isSearching = false,
  });

  CrossTabSearchState copyWith({
    String? query,
    List<TabSearchResult>? results,
    bool? isSearching,
  }) =>
      CrossTabSearchState(
        query: query ?? this.query,
        results: results ?? this.results,
        isSearching: isSearching ?? this.isSearching,
      );
}

class CrossTabSearchNotifier extends Notifier<CrossTabSearchState> {
  @override
  CrossTabSearchState build() => const CrossTabSearchState();

  void search(String query) {
    state = state.copyWith(query: query, isSearching: true);
    final results = CrossTabSearchController.instance.search(query);
    state = state.copyWith(results: results, isSearching: false);
  }

  void clear() {
    state = const CrossTabSearchState();
  }
}

final crossTabSearchProvider =
    NotifierProvider<CrossTabSearchNotifier, CrossTabSearchState>(
  CrossTabSearchNotifier.new,
);
