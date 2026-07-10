/// Widget tests for the iOS / Android `MobileShell` (v0.77.1).
///
/// Covers:
///   - the Terminal tab header surfaces a "+" affordance
///   - tapping a seeded server pushes `MobileTerminalPage`
///   - the three sibling tabs (Files / AI / Settings) are mounted
library;

import 'package:flutter/material.dart' show MaterialType, Material;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/mobile/mobile_shell.dart';
import 'package:termex/mobile/mobile_terminal_page.dart';
import 'package:termex_shared/features/server_list/models/server_dto.dart';
import 'package:termex_shared/features/server_list/state/server_provider.dart';
import 'package:termex_shared/l10n/app_localizations.dart';

ServerDto _server({
  String id = 's1',
  String name = 'prod-web',
  String host = '10.0.0.1',
}) =>
    ServerDto(
      id: id,
      name: name,
      host: host,
      port: 22,
      username: 'ubuntu',
      authType: 'password',
      sortOrder: 0,
      tags: const [],
      createdAt: '2024-01-01T00:00:00Z',
      updatedAt: '2024-01-01T00:00:00Z',
    );

class _StubServerNotifier extends ServerListNotifier {
  final List<ServerDto> _initial;
  _StubServerNotifier(this._initial);

  @override
  Future<List<ServerDto>> build() async => List.unmodifiable(_initial);
}

PageRoute<T> _route<T>(RouteSettings s, WidgetBuilder b) =>
    PageRouteBuilder<T>(settings: s, pageBuilder: (ctx, _, __) => b(ctx));

Widget _harness({required List<ServerDto> servers}) => ProviderScope(
      overrides: [
        serverListProvider
            .overrideWith(() => _StubServerNotifier(servers)),
      ],
      child: WidgetsApp(
        color: const Color(0xFF1E1E2E),
        pageRouteBuilder: _route,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Match production wrapping so xterm.dart can find its Material
        // ancestor when MobileTerminalPage builds.
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: child ?? const SizedBox(),
        ),
        home: const MobileShell(),
      ),
    );

void main() {
  testWidgets('terminal tab shows + button and empty state', (tester) async {
    await tester.pumpWidget(_harness(servers: const []));
    await tester.pumpAndSettle();

    // User-added sidebar categories (servers / proxies / snippets) render
    // "Servers" both as a category tab and as the screen header — so the
    // assertion can't be findsOneWidget anymore. We just need to confirm
    // the label is present at least once.
    expect(find.text('Servers'), findsWidgets);
    // v0.79.9: "+" text glyph was replaced with a real plus icon.
    // We still want to assert the add-server affordance exists; find
    // it by Icon widget search using the IconData constant.
    expect(
      find.byWidgetPredicate((w) =>
          w is Icon &&
          w.icon != null &&
          w.icon!.codePoint == 0xe13d /* LucideIcons.plus codepoint 57661 */),
      findsOneWidget,
    );
    expect(find.text('No servers yet'), findsOneWidget);
  });

  testWidgets('seeded server appears and tap pushes MobileTerminalPage',
      (tester) async {
    await tester.pumpWidget(_harness(servers: [_server()]));
    await tester.pumpAndSettle();

    expect(find.text('prod-web'), findsOneWidget);

    await tester.tap(find.text('prod-web'));
    // Page push animation + initial frame of MobileTerminalPage.
    await tester.pump(const Duration(milliseconds: 50));

    // Either the new page is in the widget tree, or the "Connecting…"
    // status text rendered. We accept either as proof of navigation,
    // since the SSH call will throw in unit-test mode but the page
    // itself must have been pushed.
    final pushedPage = find.byType(MobileTerminalPage);
    expect(pushedPage, findsOneWidget);
  });

  testWidgets('all four bottom tabs render', (tester) async {
    await tester.pumpWidget(_harness(servers: const []));
    await tester.pumpAndSettle();

    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Files tab shows "Files" header + same server list',
      (tester) async {
    await tester.pumpWidget(_harness(servers: [_server()]));
    await tester.pumpAndSettle();

    // BottomBar label is "Files" (one). Switching tabs should reveal the
    // header title "Files" as a second occurrence.
    expect(find.text('Files'), findsOneWidget);

    // Tap the BottomBar Files item.
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();

    // Header + bottom bar label = 2 occurrences when active.
    expect(find.text('Files'), findsNWidgets(2));
    // The seeded server still shows.
    expect(find.text('prod-web'), findsOneWidget);
  });

  testWidgets('iPad/tablet width >= 900 swaps BottomBar for NavRail',
      (tester) async {
    // Approximate an iPad in portrait: 1024 x 1366 logical pixels.
    tester.view.physicalSize = const Size(2048, 2732);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(servers: const []));
    await tester.pumpAndSettle();

    // NavRail still surfaces the 4 tab labels (rendered vertically) and
    // the Terminal tab's "Servers" header still appears, but the bottom
    // bar's container should not be present at the bottom of the layout
    // (the rail lives in a Row on the left instead).
    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    // v0.79.64: iPad terminal tab now has both the title header AND a
    // sub-tab labelled "Servers" (parity with iPhone _MobileSidebarTabs
    // — adds 代理 / 命令片段 switching to the 280pt left pane). So
    // expect at least one match instead of exactly one.
    expect(find.text('Servers'), findsAtLeastNWidgets(1));
    // Sub-tabs (Proxies + Snippets) are now reachable on iPad too.
    expect(find.text('Proxies'), findsOneWidget);
    expect(find.text('Snippets'), findsOneWidget);
  });
}
