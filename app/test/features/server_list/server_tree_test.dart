import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/server_list/models/group_dto.dart';
import 'package:termex_shared/features/server_list/models/server_dto.dart';
import 'package:termex_shared/features/server_list/state/group_provider.dart';
import 'package:termex_shared/features/server_list/state/server_provider.dart';
import 'package:termex_shared/features/server_list/widgets/server_search_bar.dart';
import 'package:termex_shared/features/sidebar_search.dart';
import 'package:termex_shared/features/server_list/widgets/server_tree.dart';
import 'package:termex_shared/l10n/app_localizations.dart';

PageRoute<T> _route<T>(RouteSettings s, WidgetBuilder b) =>
    PageRouteBuilder<T>(settings: s, pageBuilder: (ctx, _, __) => b(ctx));

ServerDto _server({
  String id = '1',
  String name = 'prod-web',
  String host = '10.0.0.1',
  String? groupId,
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
      groupId: groupId,
    );

GroupDto _group({String id = 'g1', String name = 'Production'}) => GroupDto(
      id: id,
      name: name,
      color: '#2F81F7',
      icon: 'folder',
      sortOrder: 0,
      createdAt: '',
      updatedAt: '',
    );

Widget _wrap(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: WidgetsApp(
        color: const Color(0xFF1E1E2E),
        pageRouteBuilder: _route,
        // v0.79.0 i18n: ServerTree / ServerTreeNode now call
        // AppLocalizations.of(context); without these delegates the
        // lookup returns null and the null-check operator throws.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

// ─── Stub notifiers ──────────────────────────────────────────────────────────

class _EmptyServerNotifier extends ServerListNotifier {
  @override
  Future<List<ServerDto>> build() async => [];
}

class _StubServerNotifier extends ServerListNotifier {
  final List<ServerDto> _servers;
  _StubServerNotifier(this._servers);
  @override
  Future<List<ServerDto>> build() async => _servers;
}

class _EmptyGroupNotifier extends GroupListNotifier {
  @override
  Future<List<GroupDto>> build() async => [];
}

class _StubGroupNotifier extends GroupListNotifier {
  final List<GroupDto> _groups;
  _StubGroupNotifier(this._groups);
  @override
  Future<List<GroupDto>> build() async => _groups;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('ServerTree', () {
    testWidgets('shows empty-state message when no servers', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ServerTree(),
          overrides: [
            serverListProvider.overrideWith(() => _EmptyServerNotifier()),
            groupListProvider.overrideWith(() => _EmptyGroupNotifier()),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('No servers yet.'), findsOneWidget);
    });


    // ─── Context menus ───────────────────────────────────────────────────────
    // The legacy Tauri sidebar exposed edit / duplicate / rename / move / delete
    // on a server row. The Flutter port shipped only connect + share, so these
    // pin the restored parity.

    Future<void> pumpTree(
      WidgetTester tester, {
      required List<ServerDto> servers,
      List<GroupDto> groups = const [],
    }) async {
      await tester.pumpWidget(
        _wrap(
          const ServerTree(),
          overrides: [
            serverListProvider.overrideWith(() => _StubServerNotifier(servers)),
            groupListProvider.overrideWith(() => _StubGroupNotifier(groups)),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('server row menu offers the legacy edit actions',
        (tester) async {
      await pumpTree(tester, servers: [_server()]);

      await tester.tap(find.text('prod-web'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('server row menu offers Move to Group when a group exists',
        (tester) async {
      await pumpTree(tester, servers: [_server()], groups: [_group()]);

      await tester.tap(find.text('prod-web'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Move to Group'), findsOneWidget);
    });

    testWidgets('Move to Group is hidden when there is nowhere to move',
        (tester) async {
      // No groups exist and the server is already ungrouped.
      await pumpTree(tester, servers: [_server()]);

      await tester.tap(find.text('prod-web'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Move to Group'), findsNothing);
    });

    testWidgets('a grouped server can be ungrouped even with no other group',
        (tester) async {
      await pumpTree(
        tester,
        servers: [_server(groupId: 'g1')],
        groups: [_group()],
      );

      await tester.tap(find.text('prod-web'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      // Its own group is not offered as a destination, but leaving it is.
      expect(find.text('Move to Group'), findsOneWidget);
    });

    testWidgets('a team-shared server hides edit but still allows duplicating',
        (tester) async {
      const shared = ServerDto(
        id: '2',
        name: 'team-box',
        host: '10.0.0.9',
        port: 22,
        username: 'ops',
        authType: 'password',
        sortOrder: 0,
        tags: [],
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
        teamId: 'team-1',
      );
      await pumpTree(tester, servers: [shared]);

      await tester.tap(find.text('team-box'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      // Owned by whoever shared it — editing in place would be a lie.
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Rename'), findsNothing);
      expect(find.text('Move to Group'), findsNothing);
      expect(find.text('Duplicate'), findsOneWidget);
    });


    testWidgets('blank-area menu offers create, import and export',
        (tester) async {
      await pumpTree(tester, servers: []);

      // Right-click the empty region of the tree rather than a row.
      await tester.tapAt(
        tester.getBottomLeft(find.byType(ServerTree)) - const Offset(-40, 40),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('New Connection'), findsOneWidget);
      expect(find.text('New Group'), findsOneWidget);
      expect(find.text('Export Config'), findsOneWidget);
    });


    // ─── Collapsible search ──────────────────────────────────────────────────
    // The field used to sit above the list permanently; it is now behind a
    // toggle in the section header so a short list reads as a plain list.

    testWidgets('search field is hidden until the toggle is on',
        (tester) async {
      await pumpTree(tester, servers: [_server()]);
      expect(find.byType(ServerSearchBar), findsNothing);
    });

    testWidgets('search field appears when the toggle flips on',
        (tester) async {
      final container = ProviderContainer(overrides: [
        serverListProvider.overrideWith(() => _StubServerNotifier([_server()])),
        groupListProvider.overrideWith(() => _EmptyGroupNotifier()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: WidgetsApp(
            color: const Color(0xFF1E1E2E),
            pageRouteBuilder: _route,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ServerTree(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ServerSearchBar), findsNothing);

      container.read(sidebarSearchVisibleProvider(SidebarSearchPanel.servers).notifier).state = true;
      await tester.pumpAndSettle();
      expect(find.byType(ServerSearchBar), findsOneWidget);
    });

    // Hiding the field has to drop the filter too, or rows stay missing with
    // nothing on screen explaining why.
    testWidgets('hiding the search clears an active filter', (tester) async {
      final container = ProviderContainer(overrides: [
        serverListProvider.overrideWith(
            () => _StubServerNotifier([_server(), _server(id: '2', name: 'db')])),
        groupListProvider.overrideWith(() => _EmptyGroupNotifier()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: WidgetsApp(
            color: const Color(0xFF1E1E2E),
            pageRouteBuilder: _route,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ServerTree(),
          ),
        ),
      );
      container.read(sidebarSearchVisibleProvider(SidebarSearchPanel.servers).notifier).state = true;
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText), 'db');
      await tester.pump(const Duration(milliseconds: 400));
      // 'db' also matches the text inside the field itself, so the filter is
      // asserted through the row that must disappear.
      expect(find.text('prod-web'), findsNothing);

      container.read(sidebarSearchVisibleProvider(SidebarSearchPanel.servers).notifier).state = false;
      await tester.pumpAndSettle();

      expect(find.byType(ServerSearchBar), findsNothing);
      expect(find.text('prod-web'), findsOneWidget);
    });

    testWidgets('renders a single server node', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ServerTree(),
          overrides: [
            serverListProvider
                .overrideWith(() => _StubServerNotifier([_server()])),
            groupListProvider.overrideWith(() => _EmptyGroupNotifier()),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('prod-web'), findsOneWidget);
    });

    testWidgets('renders multiple server nodes', (tester) async {
      final servers = [
        _server(id: '1', name: 'prod-web'),
        _server(id: '2', name: 'staging', host: '10.0.0.2'),
      ];
      await tester.pumpWidget(
        _wrap(
          const ServerTree(),
          overrides: [
            serverListProvider
                .overrideWith(() => _StubServerNotifier(servers)),
            groupListProvider.overrideWith(() => _EmptyGroupNotifier()),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('prod-web'), findsOneWidget);
      expect(find.text('staging'), findsOneWidget);
    });

    testWidgets('renders group header when groups present', (tester) async {
      final group = _group(id: 'g1', name: 'Production');
      final server = _server(id: '1', name: 'prod-web', groupId: 'g1');
      await tester.pumpWidget(
        _wrap(
          const ServerTree(),
          overrides: [
            serverListProvider
                .overrideWith(() => _StubServerNotifier([server])),
            groupListProvider
                .overrideWith(() => _StubGroupNotifier([group])),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Production'), findsOneWidget);
      expect(find.text('prod-web'), findsOneWidget);
    });

    testWidgets('ungrouped servers render without group header',
        (tester) async {
      final server = _server(id: '1', name: 'standalone');
      await tester.pumpWidget(
        _wrap(
          const ServerTree(),
          overrides: [
            serverListProvider
                .overrideWith(() => _StubServerNotifier([server])),
            groupListProvider
                .overrideWith(() => _StubGroupNotifier([_group()])),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('standalone'), findsOneWidget);
    });
  });
}
