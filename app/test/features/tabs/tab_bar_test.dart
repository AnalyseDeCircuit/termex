import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/tabs/state/tab_controller.dart';
import 'package:termex/features/tabs/widgets/tab_bar.dart';

PageRoute<T> _route<T>(RouteSettings s, WidgetBuilder b) =>
    PageRouteBuilder<T>(settings: s, pageBuilder: (ctx, _, __) => b(ctx));

Widget _wrap(Widget child) => ProviderScope(
      child: WidgetsApp(
        color: const Color(0xFF1E1E2E),
        pageRouteBuilder: _route,
        home: child,
      ),
    );

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('TermexTabBar', () {
    testWidgets('renders with no tabs open', (tester) async {
      await tester.pumpWidget(_wrap(const TermexTabBar()));
      await tester.pump();
      // Tab bar should render without errors; no tab chips visible.
      expect(find.byType(TermexTabBar), findsOneWidget);
    });

    testWidgets('renders tab titles from provider', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetsApp(
            color: const Color(0xFF1E1E2E),
            pageRouteBuilder: _route,
            home: Builder(
              builder: (context) {
                return const TermexTabBar();
              },
            ),
          ),
        ),
      );

      // Open two tabs via the notifier.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TermexTabBar)),
      );
      container.read(tabListProvider.notifier).openTab('s1', 'prod-web');
      container.read(tabListProvider.notifier).openTab('s2', 'staging');

      await tester.pump();

      expect(find.text('prod-web'), findsOneWidget);
      expect(find.text('staging'), findsOneWidget);
    });

    testWidgets('closing a tab removes it from the bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetsApp(
            color: const Color(0xFF1E1E2E),
            pageRouteBuilder: _route,
            home: const TermexTabBar(),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TermexTabBar)),
      );
      final id = container
          .read(tabListProvider.notifier)
          .openTab('s1', 'prod-web');
      await tester.pump();
      expect(find.text('prod-web'), findsOneWidget);

      container.read(tabListProvider.notifier).closeTab(id);
      await tester.pump();
      expect(find.text('prod-web'), findsNothing);
    });

    testWidgets('active tab changes on tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetsApp(
            color: const Color(0xFF1E1E2E),
            pageRouteBuilder: _route,
            home: const TermexTabBar(),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TermexTabBar)),
      );
      final id1 = container
          .read(tabListProvider.notifier)
          .openTab('s1', 'prod-web');
      final id2 = container
          .read(tabListProvider.notifier)
          .openTab('s2', 'staging');

      // The second tab opened is active by default.
      expect(container.read(activeTabIdProvider), id2);

      // Tap the first tab chip.
      await tester.pump();
      await tester.tap(find.text('prod-web'));
      await tester.pump();

      expect(container.read(activeTabIdProvider), id1);
    });
  });

  // ─── TabListNotifier unit tests (reuse without widget pump) ────────────────
  group('TabListNotifier — unit', () {
    ProviderContainer makeContainer() => ProviderContainer();

    test('starts empty', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      expect(c.read(tabListProvider), isEmpty);
    });

    test('openTab sets active tab', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final id = c.read(tabListProvider.notifier).openTab('s1', 'prod');
      expect(c.read(activeTabIdProvider), id);
    });

    test('closing active tab moves focus to last remaining tab', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final id1 = c.read(tabListProvider.notifier).openTab('s1', 'A');
      final id2 = c.read(tabListProvider.notifier).openTab('s2', 'B');

      // id2 is active; close it — focus should move to id1.
      c.read(tabListProvider.notifier).closeTab(id2);
      expect(c.read(activeTabIdProvider), id1);
    });

    test('closing last tab leaves activeTabId null', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final id = c.read(tabListProvider.notifier).openTab('s1', 'A');
      c.read(tabListProvider.notifier).closeTab(id);
      expect(c.read(activeTabIdProvider), isNull);
    });

    test('cloneTab produces a tab with the same serverId', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final id = c.read(tabListProvider.notifier).openTab('s1', 'A');
      c.read(tabListProvider.notifier).cloneTab(id);
      final tabs = c.read(tabListProvider);
      expect(tabs.length, 2);
      expect(tabs[0].serverId, tabs[1].serverId);
      expect(tabs[0].id, isNot(tabs[1].id));
    });
  });
}
