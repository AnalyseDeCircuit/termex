/// Cross-tab search benchmark (v0.48 spec §8).
///
/// Simulates searching a realistic scrollback across 10 active tabs.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:termex/cross_tab/cross_tab_search.dart';

class _BenchProvider implements TabScrollbackProvider {
  @override
  final String tabId;
  @override
  final String serverName;
  final List<String> _lines;

  _BenchProvider(this.tabId, this.serverName, int lineCount)
      : _lines = List.generate(
          lineCount,
          (i) => i % 20 == 0
              ? 'ERROR: connection refused on line $i'
              : 'INFO: request processed successfully line $i',
        );

  @override
  List<CrossTabMatch> search(String query) {
    final matches = <CrossTabMatch>[];
    for (var i = 0; i < _lines.length; i++) {
      if (_lines[i].contains(query)) {
        matches.add(CrossTabMatch(
          tabId: tabId,
          serverName: serverName,
          lineNumber: i,
          linePreview: _lines[i],
        ));
      }
    }
    return matches;
  }
}

void main() {
  group('CrossTabSearch benchmark', () {
    setUp(() => CrossTabSearchController.instance.clear());

    test('search 10 tabs × 1000 lines completes under 100 ms', () {
      for (var i = 0; i < 10; i++) {
        CrossTabSearchController.instance.registerTab(
          _BenchProvider('tab-$i', 'server-$i', 1000),
        );
      }

      final sw = Stopwatch()..start();
      final results = CrossTabSearchController.instance.search('ERROR');
      sw.stop();

      expect(results, isNotEmpty);
      expect(sw.elapsedMilliseconds, lessThan(100),
          reason: 'Searching 10k lines across 10 tabs must complete < 100ms');
    });
  });
}
