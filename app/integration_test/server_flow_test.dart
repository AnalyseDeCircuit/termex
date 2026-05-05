/// Integration tests for the server management flow.
///
/// These tests exercise the full Flutter widget tree end-to-end using
/// [IntegrationTestWidgetsFlutterBinding].  They are skipped in CI when the
/// required environment (real SQLCipher DB, SSH daemon) is unavailable.
///
/// Run with:
///   flutter test integration_test/server_flow_test.dart
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:termex/features/server_list/models/server_dto.dart';
import 'package:termex/features/server_list/server_list_page.dart';
import 'package:termex/features/server_list/state/server_provider.dart';
import 'package:termex/features/server_list/widgets/server_form_dialog.dart';
import 'package:termex/features/tabs/state/tab_controller.dart';

// ─── Stubs ───────────────────────────────────────────────────────────────────

ServerDto _makeServer({
  String id = '1',
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
  _StubServerNotifier([this._initial = const []]);

  final List<ServerDto> _servers = [];

  @override
  Future<List<ServerDto>> build() async {
    _servers.addAll(_initial);
    return List.unmodifiable(_servers);
  }

  @override
  Future<void> createServer(ServerInput input) async {
    final s = ServerDto(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: input.name,
      host: input.host,
      port: input.port,
      username: input.username,
      authType: input.authType,
      sortOrder: _servers.length,
      tags: const [],
      createdAt: '',
      updatedAt: '',
    );
    _servers.add(s);
    state = AsyncValue.data(List.unmodifiable(_servers));
  }

  @override
  Future<void> deleteServer(String id) async {
    _servers.removeWhere((s) => s.id == id);
    state = AsyncValue.data(List.unmodifiable(_servers));
  }
}

PageRoute<T> _route<T>(RouteSettings s, WidgetBuilder b) =>
    PageRouteBuilder<T>(settings: s, pageBuilder: (ctx, _, __) => b(ctx));

Widget _app({List<ServerDto> servers = const []}) => ProviderScope(
      overrides: [
        serverListProvider
            .overrideWith(() => _StubServerNotifier(servers)),
      ],
      child: WidgetsApp(
        color: const Color(0xFF1E1E2E),
        pageRouteBuilder: _route,
        home: const ServerListPage(),
      ),
    );

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Server list flow', () {
    testWidgets('empty state shows "No servers yet"', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('No servers yet'), findsOneWidget);
    });

    testWidgets('pre-seeded server appears in list', (tester) async {
      await tester.pumpWidget(_app(servers: [_makeServer()]));
      await tester.pumpAndSettle();
      expect(find.text('prod-web'), findsOneWidget);
      expect(find.text('ubuntu@10.0.0.1:22'), findsOneWidget);
    });

    testWidgets('multiple pre-seeded servers all appear', (tester) async {
      final servers = [
        _makeServer(id: '1', name: 'prod-web', host: '10.0.0.1'),
        _makeServer(id: '2', name: 'staging', host: '10.0.0.2'),
      ];
      await tester.pumpWidget(_app(servers: servers));
      await tester.pumpAndSettle();
      expect(find.text('prod-web'), findsOneWidget);
      expect(find.text('staging'), findsOneWidget);
    });
  });

  group('Tab flow', () {
    testWidgets('opening a tab registers it in tabListProvider', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Directly exercise the tab notifier (UI wiring for tap-to-connect
      // is completed in v0.44 once TerminalView is integrated).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ServerListPage)),
      );

      expect(container.read(tabListProvider), isEmpty);

      container.read(tabListProvider.notifier).openTab('s1', 'prod-web');
      await tester.pump();

      expect(container.read(tabListProvider).length, 1);
      expect(container.read(tabListProvider).first.title, 'prod-web');
    });

    testWidgets('closing a tab removes it', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ServerListPage)),
      );

      final id = container
          .read(tabListProvider.notifier)
          .openTab('s1', 'prod-web');
      await tester.pump();
      expect(container.read(tabListProvider).length, 1);

      container.read(tabListProvider.notifier).closeTab(id);
      await tester.pump();
      expect(container.read(tabListProvider), isEmpty);
    });
  });
}
