import 'package:flutter/material.dart'
    show DefaultMaterialLocalizations, Material, MaterialType;
import 'package:flutter/cupertino.dart'
    show DefaultCupertinoLocalizations;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/termex_bridge.dart' as bridge;

import 'src/frb_generated/frb_generated.dart';

import 'package:termex_shared/design/tokens.dart';
import 'desktop/desktop_shell.dart';
import 'package:termex_shared/features/server_list/state/app_state_provider.dart';
import 'package:termex_shared/features/server_list/widgets/master_password_dialog.dart';
import 'package:termex_shared/widgets/toast.dart';

final appInitStateProvider =
    Provider<bridge.AppInitState>((ref) => throw UnimplementedError());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TermexBridge.init();
  final initState = await bridge.initApp();
  // The Tauri-era database stores the master password as an Argon2id salt
  // + verify-token in the `settings` table, and only when the user has
  // explicitly set one. If no password is configured, init_app already
  // auto-opened the DB on the Rust side — skip the unlock dialog.
  final needsUnlock = await bridge.masterPasswordRequired();
  runApp(
    ProviderScope(
      overrides: [
        appInitStateProvider.overrideWithValue(initState),
        dbUnlockedProvider.overrideWith((_) => !needsUnlock),
      ],
      child: const TermexApp(),
    ),
  );
}

class TermexApp extends ConsumerWidget {
  const TermexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnlocked = ref.watch(dbUnlockedProvider);
    final themeData = ref.watch(themeDataProvider);
    return TermexThemeScope(
      theme: themeData,
      child: WidgetsApp(
        debugShowCheckedModeBanner: false,
        color: themeData.colors.background,
        // Material/Cupertino widgets (TextField, etc.) look up these
        // localization delegates; WidgetsApp doesn't supply them by default.
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
            PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (ctx, _, __) => builder(ctx),
        ),
        // Material(type: transparency) supplies the Material ancestor that
        // every Material widget (TabBar, ListTile, InkWell, TextField cursor
        // overlays, etc.) looks up. We use a transparent canvas so the
        // Termex theme's painted backgrounds show through unchanged.
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: TermexToastOverlay(child: child ?? const SizedBox()),
        ),
        home: isUnlocked ? const DesktopShell() : const MasterPasswordDialog(),
      ),
    );
  }
}
