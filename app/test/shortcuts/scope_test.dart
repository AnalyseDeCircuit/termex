import 'package:flutter_test/flutter_test.dart';

import 'package:termex/shortcuts/shortcut_scope.dart';

void main() {
  group('ShortcutScope', () {
    test('widget captures all lower scopes', () {
      expect(ShortcutScope.widget.captures(ShortcutScope.terminal), isTrue);
      expect(ShortcutScope.widget.captures(ShortcutScope.tab), isTrue);
      expect(ShortcutScope.widget.captures(ShortcutScope.global), isTrue);
      expect(ShortcutScope.widget.captures(ShortcutScope.widget), isTrue);
    });

    test('terminal captures terminal and below', () {
      expect(ShortcutScope.terminal.captures(ShortcutScope.terminal), isTrue);
      expect(ShortcutScope.terminal.captures(ShortcutScope.tab), isTrue);
      expect(ShortcutScope.terminal.captures(ShortcutScope.global), isTrue);
    });

    test('terminal does NOT capture widget', () {
      expect(ShortcutScope.terminal.captures(ShortcutScope.widget), isFalse);
    });

    test('global only captures global', () {
      expect(ShortcutScope.global.captures(ShortcutScope.global), isTrue);
      expect(ShortcutScope.global.captures(ShortcutScope.tab), isFalse);
      expect(ShortcutScope.global.captures(ShortcutScope.terminal), isFalse);
      expect(ShortcutScope.global.captures(ShortcutScope.widget), isFalse);
    });

    test('priorities are correctly ordered', () {
      expect(ShortcutScope.widget.priority,
          greaterThan(ShortcutScope.terminal.priority));
      expect(ShortcutScope.terminal.priority,
          greaterThan(ShortcutScope.tab.priority));
      expect(ShortcutScope.tab.priority,
          greaterThan(ShortcutScope.global.priority));
    });
  });
}
