/// BroadcastBus throughput benchmark (v0.48 spec §8).
///
/// Measures how many events per second the bus can dispatch to multiple
/// concurrent listeners.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:termex/cross_tab/broadcast_bus.dart';

void main() {
  group('BroadcastBus benchmark', () {
    test('emit 1000 SettingsChanged events under 50 ms', () async {
      final bus = BroadcastBus.instance;
      int received = 0;
      final sub = bus.on<SettingsChanged>().listen((_) => received++);

      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        bus.emit(SettingsChanged('key_$i'));
      }
      // Drain microtask queue.
      await Future<void>.delayed(Duration.zero);
      sw.stop();

      expect(received, equals(1000));
      expect(sw.elapsedMilliseconds, lessThan(50),
          reason: '1000 events dispatched in under 50ms');
      await sub.cancel();
    });

    test('5 concurrent listeners each receive all 100 events', () async {
      final bus = BroadcastBus.instance;
      final counts = List.filled(5, 0);
      final subs = [
        for (var i = 0; i < 5; i++)
          bus.on<ServerUpdated>().listen((_) => counts[i]++),
      ];

      for (var j = 0; j < 100; j++) {
        bus.emit(ServerUpdated('srv-$j'));
      }
      await Future<void>.delayed(Duration.zero);

      for (final c in counts) {
        expect(c, equals(100));
      }
      for (final s in subs) {
        await s.cancel();
      }
    });
  });
}
