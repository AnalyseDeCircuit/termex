import 'dart:io' show Platform;

import 'package:flutter/material.dart'
    show DefaultMaterialLocalizations, Material, MaterialType;
import 'package:flutter/cupertino.dart'
    show DefaultCupertinoLocalizations;
import 'package:flutter/services.dart'
    show
        DeviceOrientation,
        SystemChrome,
        SystemUiMode,
        SystemUiOverlay,
        SystemUiOverlayStyle;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:termex_bridge/termex_bridge.dart' as bridge;

import 'src/frb_generated/frb_generated.dart';

import 'package:termex_shared/design/tokens.dart';
import 'desktop/desktop_shell.dart';
import 'mobile/mobile_shell.dart';
import 'package:termex_shared/features/server_list/state/app_state_provider.dart';
import 'package:termex_shared/features/server_list/widgets/master_password_dialog.dart';
import 'package:termex_shared/system/splash_gate.dart';
import 'package:termex_shared/widgets/toast.dart';

final appInitStateProvider =
    Provider<bridge.AppInitState>((ref) => throw UnimplementedError());

// Web does not expose dart:io's Platform; this app does not target web today,
// so a direct check is safe.
bool get _isMobilePlatform => Platform.isIOS || Platform.isAndroid;

/// Result of the async bootstrap performed by `SplashGate`. Bundles
/// everything the root ProviderScope needs to override so we don't
/// re-await on rebuilds.
class _BootResult {
  final bridge.AppInitState initState;
  final bool isUnlocked;
  const _BootResult({required this.initState, required this.isUnlocked});
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mobile chrome: match Termex's dark theme on day one rather than wait
  // for the Flutter splash to fade. Edge-to-edge keeps the status / nav
  // bars transparent so the MobileShell background extends behind them.
  // Done before runApp so the very first frame already paints with the
  // right system bars.
  if (Platform.isIOS || Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.light, // Android: white icons
        statusBarBrightness: Brightness.dark, // iOS: light text
        systemNavigationBarColor: Color(0xFF161B22),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Color(0xFF161B22),
      ),
    );
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // Render the brand splash immediately, then run heavy bootstrap
  // inside the gate. On macOS / Windows / Linux this is the only
  // splash mechanism Flutter offers; on iOS / Android it visually
  // continues from the native splash (same logo + colour).
  runApp(SplashGate<_BootResult>(
    bootstrap: _bootstrap,
    builder: (context, result) => ProviderScope(
      overrides: [
        appInitStateProvider.overrideWithValue(result.initState),
        dbUnlockedProvider.overrideWith((_) => result.isUnlocked),
      ],
      child: const TermexApp(),
    ),
  ));
}

Future<_BootResult> _bootstrap() async {
  await TermexBridge.init();
  // Mobile sandboxes don't expose a writable XDG-style data dir to the
  // `dirs` Rust crate; seed the path resolver with Flutter's reported
  // application support directory. Desktop builds skip this — the Rust
  // resolver falls back to `dirs::data_dir()` which works on macOS /
  // Windows / Linux as before.
  if (Platform.isIOS || Platform.isAndroid) {
    final dir = await getApplicationSupportDirectory();
    await bridge.setAppDataDir(path: dir.path);
  }
  final initState = await bridge.initApp();
  // The Tauri-era database stores the master password as an Argon2id salt
  // + verify-token in the `settings` table, and only when the user has
  // explicitly set one. If no password is configured, init_app already
  // auto-opened the DB on the Rust side — skip the unlock dialog.
  final needsUnlock = await bridge.masterPasswordRequired();
  return _BootResult(initState: initState, isUnlocked: !needsUnlock);
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
        home: isUnlocked
            ? (_isMobilePlatform
                ? const MobileShell()
                : const DesktopShell())
            : const MasterPasswordDialog(),
      ),
    );
  }
}
