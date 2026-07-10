import 'package:flutter/widgets.dart' show Brightness;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'breakpoints.dart';

class ThemeModeNotifier extends StateNotifier<TermexThemeMode> {
  ThemeModeNotifier() : super(TermexThemeMode.system);

  void setMode(TermexThemeMode mode) => state = mode;
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, TermexThemeMode>(
  (ref) => ThemeModeNotifier(),
);

/// Live OS brightness. The root widget pushes
/// `MediaQuery.platformBrightnessOf(context)` into this provider on every
/// build, so when the OS theme flips (macOS Sonoma sunrise/sunset, Windows
/// 11 personalisation toggle, GNOME night-light) the `themeDataProvider`
/// recomputes without a restart.
final platformBrightnessProvider =
    StateProvider<Brightness>((_) => Brightness.dark);

/// Concrete theme data resolved from (mode, OS brightness). `system` /
/// `auto` consult [platformBrightnessProvider] so "follow system" actually
/// follows the OS; `light` / `dark` stay pinned regardless.
final themeDataProvider = Provider<TermexThemeData>((ref) {
  final mode = ref.watch(themeModeProvider);
  final brightness = ref.watch(platformBrightnessProvider);
  return resolveThemeData(mode, brightness);
});

final breakpointProvider = StateProvider<BreakpointState>(
  (ref) => const BreakpointState(sidebarExpanded: true, compact: false),
);
