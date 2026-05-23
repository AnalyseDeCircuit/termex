import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TerminalAction {
  clearScrollback,
  search,
  copySelection,
  paste,
}

/// When set, the active TerminalPane executes the action then clears this back
/// to null. Dispatched from desktop_shell._handleKey for Cmd+K/F/Shift+C/V.
final activeTerminalActionProvider =
    StateProvider<TerminalAction?>((ref) => null);
