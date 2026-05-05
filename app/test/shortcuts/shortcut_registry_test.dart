import 'package:flutter_test/flutter_test.dart';

import 'package:termex/shortcuts/shortcut_registry.dart';
import 'package:termex/shortcuts/shortcut_scope.dart';

void main() {
  setUp(() => ShortcutRegistry.instance.clear());

  group('ShortcutRegistry', () {
    test('register and resolve matching binding', () {
      bool fired = false;
      ShortcutRegistry.instance.register(ShortcutBinding(
        commandId: 'test.action',
        combo: const KeyCombination('cmd+t'),
        scope: ShortcutScope.global,
        handler: () => fired = true,
      ));

      final resolved = ShortcutRegistry.instance
          .resolve(const KeyCombination('cmd+t'), ShortcutScope.global);

      expect(resolved, isNotNull);
      expect(resolved!.commandId, equals('test.action'));
      resolved.handler!();
      expect(fired, isTrue);
    });

    test('resolve returns null when combo not registered', () {
      final resolved = ShortcutRegistry.instance
          .resolve(const KeyCombination('cmd+x'), ShortcutScope.global);
      expect(resolved, isNull);
    });

    test('unregister removes binding', () {
      ShortcutRegistry.instance.register(ShortcutBinding(
        commandId: 'rm.action',
        combo: const KeyCombination('ctrl+d'),
        scope: ShortcutScope.global,
      ));
      ShortcutRegistry.instance.unregister('rm.action');
      final resolved = ShortcutRegistry.instance
          .resolve(const KeyCombination('ctrl+d'), ShortcutScope.global);
      expect(resolved, isNull);
    });

    test('register overwrites existing commandId', () {
      ShortcutRegistry.instance.register(ShortcutBinding(
        commandId: 'dup.action',
        combo: const KeyCombination('cmd+a'),
        scope: ShortcutScope.global,
      ));
      ShortcutRegistry.instance.register(ShortcutBinding(
        commandId: 'dup.action',
        combo: const KeyCombination('cmd+b'),
        scope: ShortcutScope.global,
      ));
      expect(ShortcutRegistry.instance.all.length, equals(1));
      expect(
          ShortcutRegistry.instance.all.first.combo,
          equals(const KeyCombination('cmd+b')));
    });

    test('dispatch invokes handler and returns true', () {
      int count = 0;
      ShortcutRegistry.instance.register(ShortcutBinding(
        commandId: 'dispatch.action',
        combo: const KeyCombination('cmd+enter'),
        scope: ShortcutScope.global,
        handler: () => count++,
      ));
      final handled = ShortcutRegistry.instance
          .dispatch(const KeyCombination('cmd+enter'), ShortcutScope.global);
      expect(handled, isTrue);
      expect(count, equals(1));
    });

    test('dispatch returns false when no binding', () {
      final handled = ShortcutRegistry.instance
          .dispatch(const KeyCombination('cmd+zzz'), ShortcutScope.global);
      expect(handled, isFalse);
    });

    test('forScope returns only capturable bindings', () {
      ShortcutRegistry.instance.register(ShortcutBinding(
        commandId: 'global.action',
        combo: const KeyCombination('cmd+g'),
        scope: ShortcutScope.global,
      ));
      ShortcutRegistry.instance.register(ShortcutBinding(
        commandId: 'terminal.action',
        combo: const KeyCombination('cmd+f'),
        scope: ShortcutScope.terminal,
      ));

      final terminalBindings =
          ShortcutRegistry.instance.forScope(ShortcutScope.terminal);
      // Terminal scope captures both terminal and global.
      expect(terminalBindings.any((b) => b.commandId == 'global.action'), isTrue);
      expect(terminalBindings.any((b) => b.commandId == 'terminal.action'), isTrue);

      final globalBindings =
          ShortcutRegistry.instance.forScope(ShortcutScope.global);
      // Global scope captures only global, not terminal.
      expect(globalBindings.any((b) => b.commandId == 'global.action'), isTrue);
      expect(globalBindings.any((b) => b.commandId == 'terminal.action'), isFalse);
    });

    test('applyOverride changes combo without losing handler', () {
      bool fired = false;
      ShortcutRegistry.instance.register(ShortcutBinding(
        commandId: 'override.me',
        combo: const KeyCombination('cmd+o'),
        scope: ShortcutScope.global,
        handler: () => fired = true,
      ));
      ShortcutRegistry.instance
          .applyOverride('override.me', const KeyCombination('cmd+p'));
      final resolved = ShortcutRegistry.instance
          .resolve(const KeyCombination('cmd+p'), ShortcutScope.global);
      expect(resolved, isNotNull);
      resolved!.handler?.call();
      expect(fired, isTrue);
    });

    test('checkConflict detects collision', () {
      ShortcutRegistry.instance.register(ShortcutBinding(
        commandId: 'existing',
        combo: const KeyCombination('cmd+k'),
        scope: ShortcutScope.global,
      ));
      final conflict = ShortcutRegistry.instance.checkConflict(
          const KeyCombination('cmd+k'), ShortcutScope.global, 'new.action');
      expect(conflict, equals('existing'));
    });

    test('checkConflict ignores excluded commandId', () {
      ShortcutRegistry.instance.register(ShortcutBinding(
        commandId: 'self',
        combo: const KeyCombination('cmd+k'),
        scope: ShortcutScope.global,
      ));
      final conflict = ShortcutRegistry.instance.checkConflict(
          const KeyCombination('cmd+k'), ShortcutScope.global, 'self');
      expect(conflict, isNull);
    });

    test('KeyCombination equality is case-insensitive', () {
      const a = KeyCombination('Cmd+T');
      const b = KeyCombination('cmd+t');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
