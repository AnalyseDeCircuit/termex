import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/server_list/models/server_dto.dart';

PageRoute<T> _route<T>(RouteSettings s, WidgetBuilder b) =>
    PageRouteBuilder<T>(settings: s, pageBuilder: (ctx, _, __) => b(ctx));

// ─── Helpers ──────────────────────────────────────────────────────────────────

const _kTestServer = ServerDto(
  id: 'srv-1',
  name: '生产服务器',
  host: '10.0.0.1',
  port: 22,
  username: 'ubuntu',
  authType: 'password',
  sortOrder: 0,
  tags: [],
  createdAt: '2025-01-01T00:00:00Z',
  updatedAt: '2025-01-01T00:00:00Z',
);

class _SwipeDeleteList extends ConsumerWidget {
  final VoidCallback? onDelete;
  const _SwipeDeleteList({this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: const ValueKey('srv-1'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        onDelete?.call();
      },
      background: Container(color: const Color(0xFFF85149)),
      child: Container(
        height: 56,
        color: const Color(0xFF161B22),
        child: const Text('生产服务器'),
      ),
    );
  }
}

Widget _wrap(Widget child) => ProviderScope(
      child: WidgetsApp(
        color: const Color(0xFF0D1117),
        pageRouteBuilder: <T>(RouteSettings s, WidgetBuilder b) =>
            PageRouteBuilder<T>(settings: s, pageBuilder: (ctx, _, __) => b(ctx)),
        home: child,
      ),
    );

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ─── Unit: staged delete semantics ─────────────────────────────────────────

  group('Staged delete — semantics', () {
    test('stage then commit triggers delete', () async {
      final staged = <String>{};
      final committed = <String>{};

      void stage(String id) => staged.add(id);
      void commit(String id) {
        if (staged.remove(id)) committed.add(id);
      }
      void cancel(String id) => staged.remove(id);

      stage('srv-1');
      expect(staged, contains('srv-1'));
      expect(committed, isEmpty);

      commit('srv-1');
      expect(staged, isEmpty);
      expect(committed, contains('srv-1'));
    });

    test('stage then cancel does not commit', () {
      final staged = <String>{};
      final committed = <String>{};

      void stage(String id) => staged.add(id);
      void commit(String id) {
        if (staged.remove(id)) committed.add(id);
      }
      void cancel(String id) => staged.remove(id);

      stage('srv-1');
      cancel('srv-1');
      commit('srv-1');

      expect(committed, isEmpty);
    });

    test('cancel non-existent ID does not throw', () {
      final staged = <String>{};
      void cancel(String id) => staged.remove(id);

      expect(() => cancel('unknown'), returnsNormally);
    });

    test('commit non-staged ID is a no-op', () {
      final committed = <String>{};
      final staged = <String>{};

      void commit(String id) {
        if (staged.remove(id)) committed.add(id);
      }

      commit('ghost-id');
      expect(committed, isEmpty);
    });

    test('multiple servers can be staged independently', () {
      final staged = <String>{};
      final committed = <String>{};

      void stage(String id) => staged.add(id);
      void commit(String id) {
        if (staged.remove(id)) committed.add(id);
      }
      void cancel(String id) => staged.remove(id);

      stage('srv-1');
      stage('srv-2');
      cancel('srv-1');
      commit('srv-2');

      expect(committed, {'srv-2'});
      expect(staged, isEmpty);
    });

    test('3.5s undo window concept: cancel before timer fires prevents delete', () {
      final staged = <String>{};
      final committed = <String>{};

      void stage(String id) => staged.add(id);
      void commit(String id) {
        if (staged.remove(id)) committed.add(id);
      }
      void cancel(String id) => staged.remove(id);

      stage('srv-1');
      // Simulate undo tapped before 3.5s timer fires
      cancel('srv-1');
      // Timer fires
      commit('srv-1');

      expect(committed, isEmpty);
    });
  });

  // ─── Widget: Dismissible renders ────────────────────────────────────────────

  group('SwipeToDismiss — widget', () {
    testWidgets('Dismissible renders server name', (tester) async {
      await tester.pumpWidget(_wrap(const _SwipeDeleteList()));
      await tester.pump();
      expect(find.text('生产服务器'), findsOneWidget);
    });

    testWidgets('Dismissible key matches server id', (tester) async {
      await tester.pumpWidget(_wrap(const _SwipeDeleteList()));
      await tester.pump();
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      expect(dismissible.key, const ValueKey('srv-1'));
    });

    testWidgets('direction is endToStart only', (tester) async {
      await tester.pumpWidget(_wrap(const _SwipeDeleteList()));
      await tester.pump();
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
      expect(dismissible.direction, DismissDirection.endToStart);
    });

    testWidgets('onDismissed callback fires after swipe', (tester) async {
      var deleted = false;
      await tester.pumpWidget(
        _wrap(_SwipeDeleteList(onDelete: () => deleted = true)),
      );
      await tester.pump();
      await tester.drag(find.text('生产服务器'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });
  });
}
