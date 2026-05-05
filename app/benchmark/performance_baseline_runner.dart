/// Performance baseline runner (v0.52.0 §C5).
///
/// Duplicates the scenarios in the other bench files but prints actual
/// measured timings to stdout so they can be captured into
/// `docs/performance-baseline-v0.52.0.md`.
///
/// Run: `cd app && flutter test benchmark/performance_baseline_runner.dart`
library;

import 'package:flutter_test/flutter_test.dart';

// ── Stubs mirrored from the asserting benchmark files ──

class _ScrollbackBuffer {
  final int maxLines;
  final List<String> _lines = [];
  _ScrollbackBuffer({required this.maxLines});
  void append(String line) {
    _lines.add(line);
    if (_lines.length > maxLines) {
      _lines.removeRange(0, _lines.length - maxLines);
    }
  }

  int get length => _lines.length;
  List<String> viewport(int offset, int count) {
    final start = offset.clamp(0, _lines.length);
    final end = (start + count).clamp(0, _lines.length);
    return _lines.sublist(start, end);
  }
}

typedef _Handler = void Function();

class _Shortcut {
  final String keys;
  final _Handler handler;
  _Shortcut(this.keys, this.handler);
}

class _Registry {
  final Map<String, _Shortcut> _map = {};
  void register(_Shortcut s) => _map[s.keys] = s;
  bool dispatch(String keys) {
    final s = _map[keys];
    if (s == null) return false;
    s.handler();
    return true;
  }
}

void _report(String label, int micros, {String? unit}) {
  final ms = micros / 1000.0;
  final suffix = unit == null ? '' : ' ($unit)';
  // ignore: avoid_print
  print('BASELINE  $label${'.' * (48 - label.length).clamp(1, 48)} '
      '${ms.toStringAsFixed(3)} ms$suffix');
}

void main() {
  group('v0.52.0 performance baseline', () {
    test('terminal scrollback: append 10 000 lines', () {
      final buf = _ScrollbackBuffer(maxLines: 10000);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        buf.append(
            'Line $i: Lorem ipsum dolor sit amet, consectetur adipiscing elit.');
      }
      sw.stop();
      _report('terminal append 10k lines', sw.elapsedMicroseconds,
          unit: 'target <500 ms');
      expect(buf.length, equals(10000));
    });

    test('terminal scrollback: 1000 viewport calls', () {
      final buf = _ScrollbackBuffer(maxLines: 10000);
      for (var i = 0; i < 10000; i++) {
        buf.append('Line $i content');
      }
      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        buf.viewport(i % 9920, 80);
      }
      sw.stop();
      _report('terminal 1k viewport calls', sw.elapsedMicroseconds,
          unit: 'target <10 ms total');
    });

    test('broadcast bus: emit 1000 events', () async {
      final handlers = <void Function()>[];
      handlers.add(() {});
      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        for (final h in handlers) {
          h();
        }
      }
      sw.stop();
      _report('broadcast 1000 events', sw.elapsedMicroseconds,
          unit: 'target <50 ms');
    });

    test('cross-tab search: 10 tabs × 1000 lines', () {
      final tabs = <List<String>>[];
      for (var t = 0; t < 10; t++) {
        final lines = <String>[];
        for (var l = 0; l < 1000; l++) {
          lines.add(
              'tab$t line$l: the quick brown fox needle${l % 50 == 0 ? '' : ' nomatch'}');
        }
        tabs.add(lines);
      }
      final sw = Stopwatch()..start();
      var hits = 0;
      for (final tab in tabs) {
        for (final line in tab) {
          if (line.contains('needle')) hits++;
        }
      }
      sw.stop();
      _report('search 10×1000 lines', sw.elapsedMicroseconds,
          unit: 'target <100 ms');
      expect(hits, greaterThan(0));
    });

    test('shortcut dispatch: 40 bindings × 10k lookups', () {
      final reg = _Registry();
      for (var i = 0; i < 40; i++) {
        reg.register(_Shortcut('cmd+$i', () {}));
      }
      final sw = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        reg.dispatch('cmd+${i % 40}');
      }
      sw.stop();
      _report('shortcut 10k dispatches', sw.elapsedMicroseconds,
          unit: 'target <10 ms total');
    });

    test('memory leak check: 1000 create+dispose cycles', () {
      final tracker = <Object>{};
      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        final o = Object();
        tracker.add(o);
        tracker.remove(o);
      }
      sw.stop();
      _report('1000 create+dispose cycles', sw.elapsedMicroseconds,
          unit: 'target <10 ms');
      expect(tracker, isEmpty);
    });
  });
}
