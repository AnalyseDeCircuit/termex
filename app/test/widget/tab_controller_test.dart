import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/tabs/state/tab_controller.dart';

void main() {
  ProviderContainer makeContainer() => ProviderContainer();

  group('TabListNotifier', () {
    test('starts empty', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      expect(c.read(tabListProvider), isEmpty);
    });

    test('openTab adds a tab and returns its id', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final id = c.read(tabListProvider.notifier).openTab('server-1', 'prod');
      final tabs = c.read(tabListProvider);
      expect(tabs.length, 1);
      expect(tabs.first.id, id);
      expect(tabs.first.serverId, 'server-1');
      expect(tabs.first.title, 'prod');
      expect(tabs.first.status, TabStatus.connecting);
    });

    test('closeTab removes it', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final id = c.read(tabListProvider.notifier).openTab('server-1', 'prod');
      c.read(tabListProvider.notifier).closeTab(id);
      expect(c.read(tabListProvider), isEmpty);
    });

    test('cloneTab duplicates with a new id', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final id = c.read(tabListProvider.notifier).openTab('server-1', 'prod');
      c.read(tabListProvider.notifier).cloneTab(id);
      final tabs = c.read(tabListProvider);
      expect(tabs.length, 2);
      expect(tabs[0].serverId, tabs[1].serverId);
      expect(tabs[0].id, isNot(tabs[1].id));
    });

    test('updateStatus changes tab status', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final id = c.read(tabListProvider.notifier).openTab('server-1', 'prod');
      c.read(tabListProvider.notifier).updateStatus(id, TabStatus.connected);
      final tab = c.read(tabListProvider).first;
      expect(tab.status, TabStatus.connected);
    });

    test('reorderTab moves tab correctly', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final id1 = c.read(tabListProvider.notifier).openTab('s1', 'A');
      final id2 = c.read(tabListProvider.notifier).openTab('s2', 'B');
      final id3 = c.read(tabListProvider.notifier).openTab('s3', 'C');
      // Move item at index 0 to index 2 (end)
      c.read(tabListProvider.notifier).reorderTab(0, 2);
      final tabs = c.read(tabListProvider);
      expect(tabs[0].id, id2);
      expect(tabs[1].id, id1);
      expect(tabs[2].id, id3);
    });
  });

  group('activeTabProvider', () {
    test('returns null when no active tab', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      expect(c.read(activeTabProvider), isNull);
    });

    test('returns active tab when set', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final id = c.read(tabListProvider.notifier).openTab('server-1', 'prod');
      c.read(activeTabIdProvider.notifier).state = id;
      final active = c.read(activeTabProvider);
      expect(active, isNotNull);
      expect(active!.id, id);
    });
  });
}
