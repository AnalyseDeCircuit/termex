/// System tray (menu-bar) controller for Termex desktop.
///
/// v0.77.0 PC final parity: the legacy Tauri build registered a tray
/// icon via `tauri-plugin-positioner` + `tray` API; the Flutter port
/// uses `tray_manager` to deliver the same surface on macOS / Windows /
/// Linux. The menu mirrors the most common quick-actions; window-
/// visibility toggling is deferred to a follow-up that brings in
/// `window_manager` (currently not in the dependency set).
///
/// Asset: the tray icon reuses `packages/termex_shared/assets/logo/logo.png`
/// since tray_manager auto-resolves package: prefix paths.
library;

import 'dart:io' show exit;

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart' as tm;

class DesktopTray with tm.TrayListener {
  DesktopTray._();
  static final DesktopTray instance = DesktopTray._();

  bool _initialized = false;
  VoidCallback? _onNewLocalTerminal;
  VoidCallback? _onOpenSettings;

  /// Idempotent: safe to call multiple times during boot / hot restart.
  /// `onNewLocalTerminal` / `onOpenSettings` are invoked when the user
  /// picks the matching context-menu entries — wire them to the same
  /// handlers the in-app toolbar uses so behaviour stays consistent.
  Future<void> install({
    required VoidCallback onNewLocalTerminal,
    required VoidCallback onOpenSettings,
  }) async {
    if (_initialized) return;
    _initialized = true;

    _onNewLocalTerminal = onNewLocalTerminal;
    _onOpenSettings = onOpenSettings;

    // tray_manager resolves `packages/<pkg>/assets/...` paths via the
    // standard Flutter asset resolver — the same `flutter pub get`
    // run that wires termex_shared into the app makes this reachable
    // on all three desktop targets.
    try {
      await tm.trayManager
          .setIcon('packages/termex_shared/assets/logo/logo.png');
    } catch (_) {
      // Icon load failure shouldn't break boot — proceed with an empty
      // icon so the menu is still reachable from the macOS Status Bar
      // area on right-click. Real fix: ship a tray-template.png with
      // alpha-only black for the macOS menu bar style.
    }
    await tm.trayManager.setToolTip('Termex');
    await _rebuildMenu();
    tm.trayManager.addListener(this);
  }

  Future<void> _rebuildMenu() async {
    final menu = tm.Menu(items: [
      tm.MenuItem(
        key: 'new_terminal',
        label: '新建本地终端',
      ),
      tm.MenuItem(
        key: 'settings',
        label: '设置…',
      ),
      tm.MenuItem.separator(),
      tm.MenuItem(
        key: 'quit',
        label: '退出 Termex',
      ),
    ]);
    await tm.trayManager.setContextMenu(menu);
  }

  // ── TrayListener ─────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() {
    // Left-click: pop up the context menu so users get to the actions
    // in one click on macOS (where left-click on a menu-bar item is
    // the canonical way to open it). On Windows / Linux this also
    // matches the typical tray-icon UX.
    tm.trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    tm.trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(tm.MenuItem menuItem) {
    switch (menuItem.key) {
      case 'new_terminal':
        _onNewLocalTerminal?.call();
        break;
      case 'settings':
        _onOpenSettings?.call();
        break;
      case 'quit':
        // Hard-exit. Flutter's `SystemNavigator.pop()` is mobile-only;
        // on desktop the run loop only stops when the process exits.
        // Dispose tray first so the OS doesn't leave an orphan icon.
        dispose();
        exit(0);
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    tm.trayManager.removeListener(this);
    try {
      await tm.trayManager.destroy();
    } catch (_) {}
    _initialized = false;
  }
}
