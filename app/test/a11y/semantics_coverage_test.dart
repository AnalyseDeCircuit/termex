import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/design/inherited_theme.dart';
import 'package:termex_shared/design/theme.dart';
import 'package:termex_shared/layout/adaptive_layout.dart';
import 'package:termex_shared/features/terminal/font_size_toast.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: WidgetsApp(
        color: const Color(0xFF000000),
        pageRouteBuilder: <T>(RouteSettings s, WidgetBuilder b) =>
            PageRouteBuilder<T>(settings: s, pageBuilder: (ctx, _, __) => b(ctx)),
        // Sidebar widgets read theme tokens from TermexThemeScope (v0.69
        // design refactor); install a default dark theme so the
        // `assert(scope != null)` inside `TermexThemeScope.of` passes.
        home: TermexThemeScope(
          theme: TermexThemeData.dark(),
          child: child,
        ),
      ),
    );

void main() {
  // ─── SidebarHeader semantics ─────────────────────────────────────────────────

  group('SidebarHeader semantics', () {
    testWidgets('title text is accessible', (tester) async {
      await tester.pumpWidget(
        _wrap(const SidebarHeader(title: 'Servers')),
      );
      expect(find.text('Servers'), findsOneWidget);
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text('Servers')).label,
        contains('Servers'),
      );
      handle.dispose();
    });

    testWidgets('trailing widget is accessible', (tester) async {
      await tester.pumpWidget(
        _wrap(const SidebarHeader(
          title: 'Servers',
          trailing: Text('add-server'),
        )),
      );
      final handle = tester.ensureSemantics();
      expect(find.text('add-server'), findsOneWidget);
      handle.dispose();
    });
  });

  // ─── FontSizeToast semantics ─────────────────────────────────────────────────

  group('FontSizeToast semantics', () {
    testWidgets('font size label is in semantics tree', (tester) async {
      await tester.pumpWidget(
        _wrap(const FontSizeToast(fontSize: 16.0)),
      );
      await tester.pump();
      final handle = tester.ensureSemantics();
      expect(find.textContaining('16'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('boundary size labels are accessible', (tester) async {
      for (final size in [kFontSizeMin, kFontSizeMax, kFontSizeDefault]) {
        await tester.pumpWidget(_wrap(FontSizeToast(fontSize: size)));
        await tester.pump();
        expect(
          find.textContaining(size.toStringAsFixed(0)),
          findsOneWidget,
          reason: 'size $size should appear in semantics',
        );
      }
    });
  });

  // ─── Adaptive layout semantics ───────────────────────────────────────────────

  group('Adaptive layout semantics', () {
    testWidgets('sidebar layout exposes both panels to semantics tree',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SidebarDetailLayout(
            sidebar: Text('navigation'),
            detail: Text('content'),
          ),
        ),
      );
      final handle = tester.ensureSemantics();
      expect(find.text('navigation'), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
      handle.dispose();
    });
  });
}
