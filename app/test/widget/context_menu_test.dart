/// Behaviour of the shared context menu, plus a coverage check that every
/// sidebar tab wires both of its right-click menus.
///
/// Only the servers tab had context menus; proxies / snippets / recordings /
/// cloud had none at all. Adding eight menus on top of `showContextMenu`
/// surfaced two defects in it that no caller had hit hard enough to notice:
/// picking an entry never dismissed the overlay, and only the horizontal
/// position was clamped to the screen.
library;

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/design/tokens.dart';
import 'package:termex_shared/widgets/menu.dart';

Widget _host(void Function(BuildContext, Offset) onRightClick) => WidgetsApp(
      color: const Color(0xFF000000),
      pageRouteBuilder: <T>(RouteSettings s, WidgetBuilder b) =>
          PageRouteBuilder<T>(settings: s, pageBuilder: (c, _, __) => b(c)),
      home: Builder(
        builder: (context) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapUp: (d) => onRightClick(context, d.globalPosition),
          child: const SizedBox.expand(),
        ),
      ),
    );

Future<void> _rightClickAt(WidgetTester tester, Offset at) async {
  final gesture =
      await tester.startGesture(at, kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('showContextMenu', () {
    testWidgets('choosing an entry dismisses the menu', (tester) async {
      var picked = 0;
      await tester.pumpWidget(_host((context, pos) => showContextMenu(
            context: context,
            position: pos,
            items: [
              MenuItem(label: 'Refresh', onSelected: () => picked++),
            ],
          )));

      await _rightClickAt(tester, const Offset(100, 100));
      expect(find.text('Refresh'), findsOneWidget);

      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      expect(picked, 1);
      // `_MenuItemTile` only invoked `onSelected`; nothing tore the overlay
      // down, so the menu stayed on screen and the next right-click stacked
      // a second one on top of it.
      expect(find.text('Refresh'), findsNothing);
    });

    testWidgets('right-clicking twice does not stack two menus',
        (tester) async {
      await tester.pumpWidget(_host((context, pos) => showContextMenu(
            context: context,
            position: pos,
            items: [MenuItem(label: 'Refresh', onSelected: () {})],
          )));

      await _rightClickAt(tester, const Offset(100, 100));
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      await _rightClickAt(tester, const Offset(140, 160));

      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('tapping outside still dismisses', (tester) async {
      await tester.pumpWidget(_host((context, pos) => showContextMenu(
            context: context,
            position: pos,
            items: [MenuItem(label: 'Refresh', onSelected: () {})],
          )));

      await _rightClickAt(tester, const Offset(100, 100));
      expect(find.text('Refresh'), findsOneWidget);

      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();
      expect(find.text('Refresh'), findsNothing);
    });

    testWidgets('a disabled entry does not fire and leaves the menu open',
        (tester) async {
      var picked = 0;
      await tester.pumpWidget(_host((context, pos) => showContextMenu(
            context: context,
            position: pos,
            items: [
              MenuItem(label: 'Open', disabled: true, onSelected: () => picked++),
            ],
          )));

      await _rightClickAt(tester, const Offset(100, 100));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(picked, 0);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('danger entries render in the danger colour', (tester) async {
      await tester.pumpWidget(_host((context, pos) => showContextMenu(
            context: context,
            position: pos,
            items: [
              MenuItem(label: 'Keep', onSelected: () {}),
              MenuItem(label: 'Delete', danger: true, onSelected: () {}),
            ],
          )));

      await _rightClickAt(tester, const Offset(100, 100));

      Color colorOf(String label) =>
          tester.widget<Text>(find.text(label)).style!.color!;

      // The server tree's bespoke menu already painted destructive entries
      // red; the shared menu had no notion of it, so the same action looked
      // different tab to tab.
      expect(colorOf('Delete'), TermexColorScheme.dark().danger);
      expect(colorOf('Keep'), isNot(TermexColorScheme.dark().danger));
    });

    testWidgets('a menu near the bottom edge stays on screen', (tester) async {
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.pumpWidget(_host((context, pos) => showContextMenu(
            context: context,
            position: pos,
            items: [
              for (var i = 0; i < 8; i++)
                MenuItem(label: 'Item $i', onSelected: () {}),
            ],
          )));

      // Right-click just above the bottom edge: the menu is taller than the
      // remaining space, so it must flip above the pointer. Only dx was
      // clamped before, leaving the lower entries unreachable.
      await _rightClickAt(tester, Offset(100, size.height - 20));

      final lastItem = tester.getRect(find.text('Item 7'));
      expect(lastItem.bottom, lessThanOrEqualTo(size.height));
      expect(tester.getRect(find.text('Item 0')).top, greaterThanOrEqualTo(0.0));
    });
  });

  group('every sidebar tab wires both right-click menus', () {
    // Source check: these panels build from FRB data, so pumping them needs a
    // live bridge. What is pinned is the wiring — a panel-level handler on an
    // opaque detector (blank area) and a row-level one (node).
    const panelLevel = <String, String>{
      'servers': 'features/server_list/widgets/server_tree.dart',
      'proxies': 'features/proxy/proxy_panel.dart',
      'snippets': 'features/snippet/snippet_library.dart',
      'recordings': 'features/recording/recording_list_panel.dart',
      'cloud': 'features/cloud/cloud_panel.dart',
    };
    const rowLevel = <String, String>{
      'servers': 'features/server_list/widgets/server_tree_node.dart',
      'proxies': 'features/proxy/proxy_panel.dart',
      'snippets': 'features/snippet/snippet_row.dart',
      'recordings': 'features/recording/recording_list_panel.dart',
      'cloud': 'features/cloud/cloud_panel.dart',
    };

    Directory repoRoot() {
      var dir = Directory.current;
      while (!(Directory('${dir.path}/app/lib').existsSync() &&
          Directory('${dir.path}/packages/termex_shared/lib').existsSync())) {
        final parent = dir.parent;
        if (parent.path == dir.path) fail('repo root not found');
        dir = parent;
      }
      return dir;
    }

    final base = '${repoRoot().path}/packages/termex_shared/lib/';

    panelLevel.forEach((tab, rel) {
      test('$tab — blank area', () {
        final src = File('$base$rel').readAsStringSync();
        expect(src.contains('onSecondaryTap'), isTrue,
            reason: '$rel has no blank-area right-click handler');
        expect(src.contains('HitTestBehavior.opaque'), isTrue,
            reason: '$rel: without opaque hit-testing, empty space below the '
                'last row swallows the right-click');
      });
    });

    rowLevel.forEach((tab, rel) {
      test('$tab — node', () {
        final src = File('$base$rel').readAsStringSync();
        expect(src.contains('onSecondaryTap'), isTrue,
            reason: '$rel has no per-row right-click handler');
      });
    });
  });
}
