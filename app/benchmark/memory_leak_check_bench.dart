/// MemoryLeakCheck counter throughput benchmark (v0.48 spec §8 / §9).
///
/// Ensures the object-counting registry has negligible overhead so it can
/// stay enabled in debug builds.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:termex/performance/memory_leak_check.dart';

void main() {
  group('MemoryLeakCheck benchmark', () {
    setUp(() {
      MemoryLeakCheck.reset();
      MemoryLeakCheck.enable();
    });

    test('1 000 create+dispose cycles complete under 10 ms', () {
      const type = 'TerminalSession';
      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        MemoryLeakCheck.onCreated(type);
        MemoryLeakCheck.onDisposed(type);
      }
      sw.stop();
      expect(MemoryLeakCheck.liveSnapshot()[type], equals(0));
      expect(sw.elapsedMilliseconds, lessThan(10),
          reason: '1k create+dispose cycles must complete < 10ms');
    });

    test('allDisposed returns true after balanced create/dispose', () {
      MemoryLeakCheck.onCreated('A');
      MemoryLeakCheck.onCreated('B');
      MemoryLeakCheck.onDisposed('A');
      MemoryLeakCheck.onDisposed('B');
      expect(MemoryLeakCheck.allDisposed(), isTrue);
    });

    test('allDisposed returns false with leaked object', () {
      MemoryLeakCheck.onCreated('LeakyType');
      expect(MemoryLeakCheck.allDisposed(), isFalse);
    });
  });
}
