/// Shortcut dispatch latency benchmark (v0.48 spec §8).
///
/// Asserts that resolving a shortcut in a registry with 40 bindings
/// completes in well under 1 ms (target: < 0.1 ms per lookup).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:termex/shortcuts/shortcut_registry.dart';
import 'package:termex/shortcuts/shortcut_scope.dart';

void main() {
  group('Shortcut dispatch benchmark', () {
    setUp(() => ShortcutRegistry.instance.clear());

    test('resolve with 40 bindings under 10 ms for 10k iterations', () {
      // Populate registry with ~40 bindings.
      for (var i = 0; i < 40; i++) {
        ShortcutRegistry.instance.register(ShortcutBinding(
          commandId: 'cmd.$i',
          combo: KeyCombination('ctrl+${i.toRadixString(36)}'),
          scope: ShortcutScope.global,
        ));
      }

      final sw = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        ShortcutRegistry.instance
            .resolve(const KeyCombination('ctrl+z'), ShortcutScope.global);
      }
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(10),
          reason: '10k resolve calls on 40-binding registry must complete < 10ms');
    });

    test('dispatch hit calls handler within 1ms', () {
      int fired = 0;
      ShortcutRegistry.instance.register(ShortcutBinding(
        commandId: 'bench.action',
        combo: const KeyCombination('cmd+enter'),
        scope: ShortcutScope.global,
        handler: () => fired++,
      ));

      final sw = Stopwatch()..start();
      ShortcutRegistry.instance
          .dispatch(const KeyCombination('cmd+enter'), ShortcutScope.global);
      sw.stop();

      expect(fired, equals(1));
      expect(sw.elapsedMicroseconds, lessThan(1000),
          reason: 'Single dispatch must complete in under 1ms');
    });
  });
}
