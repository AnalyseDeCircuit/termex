import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/server_list/models/server_dto.dart';
import 'package:termex/features/server_list/server_list_page.dart';
import 'package:termex/features/server_list/state/server_provider.dart';

PageRoute<T> _route<T>(RouteSettings s, WidgetBuilder b) =>
    PageRouteBuilder<T>(settings: s, pageBuilder: (ctx, _, __) => b(ctx));

ServerDto _makeServer({
  String id = '1',
  String name = 'prod-web',
  String host = '10.0.0.1',
  int port = 22,
  String username = 'ubuntu',
}) =>
    ServerDto(
      id: id,
      name: name,
      host: host,
      port: port,
      username: username,
      authType: 'password',
      sortOrder: 0,
      tags: const [],
      createdAt: '2024-01-01T00:00:00Z',
      updatedAt: '2024-01-01T00:00:00Z',
    );

void main() {
  testWidgets('shows "No servers yet" when list is empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverListProvider.overrideWith(() => _EmptyServerListNotifier()),
        ],
        child: WidgetsApp(
          color: Color(0xFF1E1E2E),
          pageRouteBuilder: _route,
          home: ServerListPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('No servers yet'), findsOneWidget);
  });

  testWidgets('renders server names from list', (tester) async {
    final server = _makeServer();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverListProvider
              .overrideWith(() => _StubServerListNotifier([server])),
        ],
        child: WidgetsApp(
          color: Color(0xFF1E1E2E),
          pageRouteBuilder: _route,
          home: ServerListPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('prod-web'), findsOneWidget);
    expect(find.text('ubuntu@10.0.0.1:22'), findsOneWidget);
  });

  testWidgets('renders multiple servers', (tester) async {
    final servers = [
      _makeServer(id: '1', name: 'prod-web', host: '10.0.0.1'),
      _makeServer(id: '2', name: 'staging', host: '10.0.0.2', username: 'root'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverListProvider
              .overrideWith(() => _StubServerListNotifier(servers)),
        ],
        child: WidgetsApp(
          color: Color(0xFF1E1E2E),
          pageRouteBuilder: _route,
          home: ServerListPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('prod-web'), findsOneWidget);
    expect(find.text('staging'), findsOneWidget);
  });
}

class _EmptyServerListNotifier extends ServerListNotifier {
  @override
  Future<List<ServerDto>> build() async => [];
}

class _StubServerListNotifier extends ServerListNotifier {
  final List<ServerDto> _servers;
  _StubServerListNotifier(this._servers);

  @override
  Future<List<ServerDto>> build() async => _servers;
}
