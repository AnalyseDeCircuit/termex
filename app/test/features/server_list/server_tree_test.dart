import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/server_list/models/group_dto.dart';
import 'package:termex/features/server_list/models/server_dto.dart';
import 'package:termex/features/server_list/state/group_provider.dart';
import 'package:termex/features/server_list/state/server_provider.dart';
import 'package:termex/features/server_list/widgets/server_tree.dart';

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
