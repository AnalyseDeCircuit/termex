import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/design/inherited_theme.dart';
import 'package:termex_shared/design/theme.dart';
import 'package:termex_shared/layout/adaptive_layout.dart';

Widget _app({required double width, required Widget child}) => ProviderScope(
      child: WidgetsApp(
        color: const Color(0xFF000000),
        pageRouteBuilder: <T>(RouteSettings s, WidgetBuilder b) =>
            PageRouteBuilder<T>(settings: s, pageBuilder: (ctx, _, __) => b(ctx)),
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 1024)),
          // Sidebar widgets read tokens from TermexThemeScope (v0.69 design
          // refactor); install a default dark theme so they don't assert.
          child: TermexThemeScope(
            theme: TermexThemeData.dark(),
            child: child,
          ),
        ),
      ),
    );

void main() {
  group('iPad sidebar row height', () {
    testWidgets('SidebarHeader height is 52px (≥ 44pt minimum)', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 1024,
          child: const SidebarHeader(title: 'Servers'),
        ),
      );
      final box = tester.getSize(find.byType(SidebarHeader));
      expect(box.height, greaterThanOrEqualTo(44));
    });

    testWidgets('SidebarDetailLayout places sidebar before detail', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 1024,
          child: const SidebarDetailLayout(
            sidebar: Text('sidebar-content'),
            detail: Text('detail-content'),
          ),
        ),
      );
      final sidebarPos = tester.getTopLeft(find.text('sidebar-content'));
      final detailPos = tester.getTopLeft(find.text('detail-content'));
      // Sidebar should be to the left of the detail area.
      expect(sidebarPos.dx, lessThan(detailPos.dx));
    });

    testWidgets('SidebarDetailLayout sidebar is 280px wide by default',
        (tester) async {
      await tester.pumpWidget(
        _app(
          width: 1024,
          child: const SidebarDetailLayout(
            sidebar: SizedBox.shrink(),
            detail: SizedBox.shrink(),
          ),
        ),
      );
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(sizedBoxes.any((b) => b.width == 280), isTrue);
    });

    testWidgets('adaptive layout shows bottombar on narrow iPad (744px)',
        (tester) async {
      await tester.pumpWidget(
        _app(
          width: 744,
          child: TermexAdaptiveLayout(
            sidebarBuilder: (_) => const Text('sidebar'),
            bottomBarBuilder: (_) => const Text('bottombar'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('bottombar'), findsOneWidget);
    });

    testWidgets('adaptive layout shows sidebar on iPad 1024px', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 1024,
          child: TermexAdaptiveLayout(
            sidebarBuilder: (_) => const Text('sidebar'),
            bottomBarBuilder: (_) => const Text('bottombar'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('sidebar'), findsOneWidget);
    });

    testWidgets('split view 500px falls back to bottombar', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 500,
          child: TermexAdaptiveLayout(
            sidebarBuilder: (_) => const Text('sidebar'),
            bottomBarBuilder: (_) => const Text('bottombar'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('bottombar'), findsOneWidget);
    });
  });
}
