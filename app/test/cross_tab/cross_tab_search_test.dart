import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:termex/cross_tab/cross_tab_search.dart';

class _FakeProvider implements TabScrollbackProvider {
  @override
  final String tabId;
  @override
  final String serverName;
  final List<String> lines;

  _FakeProvider(this.tabId, this.serverName, this.lines);

  @override
  List<CrossTabMatch> search(String query) {
    final matches = <CrossTabMatch>[];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains(query)) {
        matches.add(CrossTabMatch(
          tabId: tabId,
          serverName: serverName,
          lineNumber: i,
          linePreview: lines[i],
        ));
      }
    }
    return matches;
  }
}

void main() {
  setUp(() {
    CrossTabSearchController.instance.clear();
  });

  group('CrossTabSearchController', () {
    test('search returns empty list for empty query', () {
      final results =
          CrossTabSearchController.instance.search('');
      expect(results, isEmpty);
    });

    test('search finds matches across registered tabs', () {
      CrossTabSearchController.instance.registerTab(
        _FakeProvider('tab-1', 'web-01', ['error: timeout', 'ok', 'error: refused']),
      );
      CrossTabSearchController.instance.registerTab(
        _FakeProvider('tab-2', 'db-01', ['select * from users', 'postgres error']),
      );

      final results =
          CrossTabSearchController.instance.search('error');
      expect(results, hasLength(2));

      final tab1 = results.firstWhere((r) => r.tabId == 'tab-1');
      expect(tab1.count, equals(2));

      final tab2 = results.firstWhere((r) => r.tabId == 'tab-2');
      expect(tab2.count, equals(1));
    });

    test('tabs with no matches are omitted', () {
      CrossTabSearchController.instance.registerTab(
        _FakeProvider('tab-1', 'srv', ['hello world']),
      );
      final results =
          CrossTabSearchController.instance.search('error');
      expect(results, isEmpty);
    });

    test('unregisterTab removes tab from search', () {
      CrossTabSearchController.instance.registerTab(
        _FakeProvider('tab-1', 'srv', ['error here']),
      );
      CrossTabSearchController.instance.unregisterTab('tab-1');
      final results =
          CrossTabSearchController.instance.search('error');
      expect(results, isEmpty);
    });
  });

  group('CrossTabSearchNotifier', () {
    test('search updates state.results', () {
      CrossTabSearchController.instance.registerTab(
        _FakeProvider('tab-x', 'srv', ['connection error']),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(crossTabSearchProvider.notifier).search('error');
      final state = container.read(crossTabSearchProvider);
      expect(state.query, equals('error'));
      expect(state.results, isNotEmpty);
      expect(state.isSearching, isFalse);
    });

    test('clear resets state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(crossTabSearchProvider.notifier).search('x');
      container.read(crossTabSearchProvider.notifier).clear();
      final state = container.read(crossTabSearchProvider);
      expect(state.query, isEmpty);
      expect(state.results, isEmpty);
    });
  });
}
