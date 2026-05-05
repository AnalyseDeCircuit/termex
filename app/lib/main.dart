import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/termex_bridge.dart' as bridge;

import 'design/tokens.dart';
import 'features/server_list/server_list_page.dart';
import 'platform/unlock_page.dart';

final appInitStateProvider =
    Provider<bridge.AppInitState>((ref) => throw UnimplementedError());

final appUnlockedProvider = StateProvider<bool>((ref) => false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initState = await bridge.initApp();
  runApp(
    ProviderScope(
      overrides: [appInitStateProvider.overrideWithValue(initState)],
      child: const TermexApp(),
    ),
  );
}

class TermexApp extends ConsumerWidget {
  const TermexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnlocked = ref.watch(appUnlockedProvider);
    final themeData = ref.watch(themeDataProvider);
    return TermexThemeScope(
      theme: themeData,
      child: WidgetsApp(
        color: themeData.colors.background,
        pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
            PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (ctx, _, __) => builder(ctx),
        ),
        home: isUnlocked ? const ServerListPage() : const UnlockPage(),
      ),
    );
  }
}
