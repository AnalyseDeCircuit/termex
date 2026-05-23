import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/design/inherited_theme.dart';
import 'package:termex_shared/design/theme.dart';
import 'package:termex_shared/layout/adaptive_layout.dart';

// Minimal WidgetsApp wrapper so MediaQuery is available.  The shared
// SidebarHeader / SidebarDetailLayout widgets now read theme tokens from
// [TermexThemeScope] (added during the v0.69 design refactor), so the wrapper
// installs a default dark theme.
Widget _app({required double width, required Widget child}) =>
    ProviderScope(
      child: WidgetsApp(
        color: const Color(0xFF000000),
        pageRouteBuilder: <T>(RouteSettings s, WidgetBuilder b) =>
            PageRouteBuilder<T>(settings: s, pageBuilder: (ctx, _, __) => b(ctx)),
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: TermexThemeScope(
            theme: TermexThemeData.dark(),
            child: child,
          ),
        ),
      ),
    );

void main() {
  // ─── layoutModeFor ──────────────────────────────────────────────────────────

  group('layoutModeFor', () {
    test('returns bottomBar below 900', () {
      expect(layoutModeFor(375), LayoutMode.bottomBar);
      expect(layoutModeFor(600), LayoutMode.bottomBar);
      expect(layoutModeFor(899), LayoutMode.bottomBar);
    });

    test('returns sidebar at exactly 900', () {
      expect(layoutModeFor(900), LayoutMode.sidebar);
    });

    test('returns sidebar above 900', () {
      expect(layoutModeFor(1024), LayoutMode.sidebar);
      expect(layoutModeFor(1366), LayoutMode.sidebar);
    });
  });

  // ─── TermexAdaptiveLayout widget ────────────────────────────────────────────

  group('TermexAdaptiveLayout', () {
    testWidgets('shows bottomBar at 600px', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 600,
          child: TermexAdaptiveLayout(
            sidebarBuilder: (_) => const Text('sidebar'),
            bottomBarBuilder: (_) => const Text('bottombar'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('bottombar'), findsOneWidget);
      expect(find.text('sidebar'), findsNothing);
    });

    testWidgets('shows sidebar at 1024px', (tester) async {
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
      expect(find.text('bottombar'), findsNothing);
    });

    testWidgets('shows bottomBar at exactly 899px', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 899,
          child: TermexAdaptiveLayout(
            sidebarBuilder: (_) => const Text('sidebar'),
            bottomBarBuilder: (_) => const Text('bottombar'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('bottombar'), findsOneWidget);
    });

    testWidgets('shows sidebar at exactly 900px', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 900,
          child: TermexAdaptiveLayout(
            sidebarBuilder: (_) => const Text('sidebar'),
            bottomBarBuilder: (_) => const Text('bottombar'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('sidebar'), findsOneWidget);
    });
  });

  // ─── SidebarDetailLayout ────────────────────────────────────────────────────

  group('SidebarDetailLayout', () {
    testWidgets('renders sidebar and detail panels', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 1024,
          child: const SidebarDetailLayout(
            sidebar: Text('nav'),
            detail: Text('content'),
          ),
        ),
      );
      expect(find.text('nav'), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('sidebar has default 280px width', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 1024,
          child: const SidebarDetailLayout(
            sidebar: SizedBox.shrink(),
            detail: SizedBox.shrink(),
          ),
        ),
      );
      // Find the SizedBox(width: 280) inside _SidebarPanel.
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(sizedBoxes.any((b) => b.width == 280), isTrue);
    });

    testWidgets('custom sidebarWidth is respected', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 1024,
          child: const SidebarDetailLayout(
            sidebar: SizedBox.shrink(),
            detail: SizedBox.shrink(),
            sidebarWidth: 320,
          ),
        ),
      );
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(sizedBoxes.any((b) => b.width == 320), isTrue);
    });
  });

  // ─── SidebarHeader ──────────────────────────────────────────────────────────

  group('SidebarHeader', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 1024,
          child: const SidebarHeader(title: 'Servers'),
        ),
      );
      expect(find.text('Servers'), findsOneWidget);
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 1024,
          child: const SidebarHeader(
            title: 'Servers',
            trailing: Text('add'),
          ),
        ),
      );
      expect(find.text('add'), findsOneWidget);
    });

    testWidgets('has minimum 52px height', (tester) async {
      await tester.pumpWidget(
        _app(
          width: 1024,
          child: const SidebarHeader(title: 'Servers'),
        ),
      );
      final header = tester.firstWidget<SizedBox>(
        find.descendant(
          of: find.byType(SidebarHeader),
          matching: find.byType(SizedBox),
        ),
      );
      expect(header.height, greaterThanOrEqualTo(52));
    });
  });
}
