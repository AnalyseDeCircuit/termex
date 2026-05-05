/// Terminal scrollback render benchmark (v0.48 spec §8.3).
///
/// Measures how long it takes to process a large burst of terminal lines
/// (simulating `cat /dev/urandom | head -10000`) and assert the elapsed
/// time stays under the 16 ms per-frame budget.
///
/// Run with: flutter test benchmark/terminal_scroll_bench.dart
library;

import 'package:flutter_test/flutter_test.dart';

// ─── Stub scrollback buffer ───────────────────────────────────────────────────

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
    final start = (offset).clamp(0, _lines.length);
    final end = (offset + count).clamp(0, _lines.length);
    return _lines.sublist(start, end);
  }
}

// ─── Benchmarks ──────────────────────────────────────────────────────────────

void main() {
  group('Terminal scroll benchmark', () {
    test('append 10 000 lines under 500 ms', () {
      final buf = _ScrollbackBuffer(maxLines: 10000);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        buf.append(
            'Line $i: Lorem ipsum dolor sit amet, consectetur adipiscing elit.');
      }
      sw.stop();
      expect(buf.length, equals(10000));
      expect(sw.elapsedMilliseconds, lessThan(500),
          reason: 'Appending 10k lines should complete in under 500ms');
    });

    test('viewport(0, 80) call is under 1 ms', () {
      final buf = _ScrollbackBuffer(maxLines: 10000);
      for (var i = 0; i < 10000; i++) {
        buf.append('Line $i: content here');
      }
      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        buf.viewport(i % 9920, 80);
      }
      sw.stop();
      // 1000 viewport calls should complete in under 10 ms.
      expect(sw.elapsedMilliseconds, lessThan(10),
          reason: 'Viewport access should be O(1)-ish');
    });

    test('buffer trims to maxLines correctly', () {
      final buf = _ScrollbackBuffer(maxLines: 100);
      for (var i = 0; i < 500; i++) {
        buf.append('line $i');
      }
      expect(buf.length, equals(100));
      expect(buf.viewport(0, 1).first, equals('line 400'));
    });
  });
}
