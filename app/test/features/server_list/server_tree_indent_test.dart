/// Leading indent of sidebar server rows.
///
/// A server row has no chevron; the column exists only so its icon lines up
/// under the group rows above it. It was reserved unconditionally, so a flat
/// list with no groups showed 32px of empty gutter before the icon
/// (4 list padding + 8 row padding + 16 spacer + 4 gap) — and the spacer was
/// 16px against a 12px chevron, so it did not even align when groups existed.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/server_list/widgets/server_tree_node.dart';
import 'package:termex_shared/l10n/app_localizations.dart';

Widget _host(Widget child) => WidgetsApp(
      color: const Color(0xFF000000),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      pageRouteBuilder: <T>(RouteSettings s, WidgetBuilder b) =>
          PageRouteBuilder<T>(settings: s, pageBuilder: (c, _, __) => b(c)),
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 240, child: child),
      ),
    );

Widget _server({required bool reserveExpandSpace, int depth = 0}) =>
    ServerTreeNode(
      isGroup: false,
      id: 's1',
      name: 'weft',
      subtitle: 'huzou@192.168.1.10:22',
      isExpanded: false,
      isSelected: false,
      depth: depth,
      reserveExpandSpace: reserveExpandSpace,
    );

/// Left edge of the row's leading icon, relative to the row itself.
double _iconInset(WidgetTester tester) {
  final row = tester.getRect(find.byType(ServerTreeNode));
  final icon = tester.getRect(find.byType(Icon).first);
  return icon.left - row.left;
}

void main() {
  testWidgets('a flat list drops the chevron gutter', (tester) async {
    await tester.pumpWidget(_host(_server(reserveExpandSpace: false)));
    // Row padding only — no chevron column to skip past.
    expect(_iconInset(tester), 8.0);
  });

  testWidgets('the gutter is kept when groups exist, so icons align',
      (tester) async {
    await tester.pumpWidget(_host(_server(reserveExpandSpace: true)));
    // 8 row padding + 12 chevron column + 4 gap.
    expect(_iconInset(tester), 24.0);
  });

  testWidgets('dropping the gutter reclaims exactly the chevron column',
      (tester) async {
    await tester.pumpWidget(_host(_server(reserveExpandSpace: true)));
    final withGutter = _iconInset(tester);
    await tester.pumpWidget(_host(_server(reserveExpandSpace: false)));
    final without = _iconInset(tester);
    expect(withGutter - without, 16.0); // 12px column + its 4px gap
  });

  testWidgets('nesting depth still indents', (tester) async {
    await tester.pumpWidget(
      _host(_server(reserveExpandSpace: true, depth: 2)),
    );
    // A nested row implies groups exist, so the gutter stays and depth adds
    // 8px per level on top of it.
    expect(_iconInset(tester), 24.0 + 16.0);
  });

  testWidgets('a group row keeps its chevron regardless of the flag',
      (tester) async {
    await tester.pumpWidget(_host(const ServerTreeNode(
      isGroup: true,
      id: 'g1',
      name: 'Production',
      isExpanded: false,
      isSelected: false,
      reserveExpandSpace: false,
    )));
    // The chevron is a real control on a group row, not padding, so the flag
    // must not remove it. It renders as the first Icon, at the row padding;
    // the folder icon follows it in the reserved column.
    final row = tester.getRect(find.byType(ServerTreeNode));
    final icons = tester.widgetList<Icon>(find.byType(Icon)).length;
    expect(icons, greaterThanOrEqualTo(2), reason: 'chevron + folder');
    expect(tester.getRect(find.byType(Icon).at(0)).left - row.left, 8.0);
    expect(tester.getRect(find.byType(Icon).at(1)).left - row.left, 24.0);
  });
}
