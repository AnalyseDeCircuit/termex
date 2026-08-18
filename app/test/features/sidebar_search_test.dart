import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/sidebar_search.dart';

void main() {
  group('sidebarSearchVisibleProvider', () {
    test('every panel starts collapsed', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      for (final p in [
        SidebarSearchPanel.servers,
        SidebarSearchPanel.proxies,
        SidebarSearchPanel.snippets,
        SidebarSearchPanel.recordings,
      ]) {
        expect(c.read(sidebarSearchVisibleProvider(p)), isFalse, reason: p);
      }
    });

    // Keyed per panel so opening search in one category does not silently
    // filter another when the user switches tabs.
    test('panels toggle independently', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      c.read(sidebarSearchVisibleProvider(SidebarSearchPanel.proxies).notifier)
          .state = true;

      expect(
          c.read(sidebarSearchVisibleProvider(SidebarSearchPanel.proxies)),
          isTrue);
      expect(
          c.read(sidebarSearchVisibleProvider(SidebarSearchPanel.servers)),
          isFalse);
      expect(
          c.read(sidebarSearchVisibleProvider(SidebarSearchPanel.snippets)),
          isFalse);
      expect(
          c.read(sidebarSearchVisibleProvider(SidebarSearchPanel.recordings)),
          isFalse);
    });
  });
}
