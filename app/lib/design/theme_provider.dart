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

final themeDataProvider = Provider<TermexThemeData>((ref) {
  final mode = ref.watch(themeModeProvider);
  if (mode == TermexThemeMode.light) return TermexThemeData.light();
  return TermexThemeData.dark();
});

final breakpointProvider = StateProvider<BreakpointState>(
  (ref) => const BreakpointState(sidebarExpanded: true, compact: false),
);
