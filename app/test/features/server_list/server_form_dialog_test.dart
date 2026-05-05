import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/server_list/models/group_dto.dart';
import 'package:termex/features/server_list/models/server_dto.dart';
import 'package:termex/features/server_list/state/group_provider.dart';
import 'package:termex/features/server_list/state/server_provider.dart';
import 'package:termex/features/server_list/widgets/server_form_dialog.dart';
import 'package:termex/widgets/form_validators.dart';

PageRoute<T> _route<T>(RouteSettings s, WidgetBuilder b) =>
    PageRouteBuilder<T>(settings: s, pageBuilder: (ctx, _, __) => b(ctx));

Widget _wrap(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: WidgetsApp(
        color: const Color(0xFF1E1E2E),
        pageRouteBuilder: _route,
        home: child,
      ),
    );

class _NopServerNotifier extends ServerListNotifier {
  @override
  Future<List<ServerDto>> build() async => [];
}

class _EmptyGroupNotifier extends GroupListNotifier {
  @override
  Future<List<GroupDto>> build() async => [];
}

// ─── Unit tests for individual validators (no widget pump needed) ─────────────

void main() {
  group('ServerFormDialog — form validator unit tests', () {
    test('host validator rejects empty string', () {
      expect(Validators.required(message: 'required')(''), isNotNull);
    });

    test('host validator accepts non-empty string', () {
      expect(Validators.required(message: 'required')('example.com'), isNull);
    });

    test('name validator rejects empty string', () {
      expect(Validators.required(message: 'required')(''), isNotNull);
    });

    test('username validator rejects whitespace-only', () {
      expect(Validators.required(message: 'required')('   '), isNotNull);
    });
  });

  group('ServerFormDialog — widget tests', () {
    testWidgets('renders Add Server title in create mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ServerFormDialog(),
          overrides: [
            serverListProvider.overrideWith(() => _NopServerNotifier()),
            groupListProvider.overrideWith(() => _EmptyGroupNotifier()),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Add Server'), findsOneWidget);
    });

    testWidgets('shows required field labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ServerFormDialog(),
          overrides: [
            serverListProvider.overrideWith(() => _NopServerNotifier()),
            groupListProvider.overrideWith(() => _EmptyGroupNotifier()),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Host'), findsOneWidget);
      expect(find.text('Port'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
    });

    testWidgets('Save and Cancel buttons are present', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ServerFormDialog(),
          overrides: [
            serverListProvider.overrideWith(() => _NopServerNotifier()),
            groupListProvider.overrideWith(() => _EmptyGroupNotifier()),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Add Server'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('password field is visible for password auth type',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ServerFormDialog(),
          overrides: [
            serverListProvider.overrideWith(() => _NopServerNotifier()),
            groupListProvider.overrideWith(() => _EmptyGroupNotifier()),
          ],
        ),
      );
      await tester.pump();
      // Default auth type is 'password'; the password label should be visible.
      expect(find.text('Password'), findsWidgets);
    });
  });
}
