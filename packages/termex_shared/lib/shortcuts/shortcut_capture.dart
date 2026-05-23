/// Keyboard shortcut capture widget (v0.48 spec §4).
///
/// Wraps a subtree and intercepts key events.  When a matching binding exists
/// for the current [scope], its handler is called and the event is consumed.
library;

import 'package:flutter/material.dart' hide ShortcutRegistry;
import 'package:flutter/services.dart';

import 'shortcut_registry.dart';
import 'shortcut_scope.dart';

class ShortcutCapture extends StatelessWidget {
  final ShortcutScope scope;
  final Widget child;

  const ShortcutCapture({
    super.key,
    required this.scope,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final combo = _buildCombo(event);
        if (combo == null) return KeyEventResult.ignored;
        final handled =
            ShortcutRegistry.instance.dispatch(KeyCombination(combo), scope);
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: child,
    );
  }

  static String? _buildCombo(KeyDownEvent event) {
    final parts = <String>[];

    final isCmd = HardwareKeyboard.instance.isMetaPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    if (isCmd) parts.add('cmd');
    if (isCtrl) parts.add('ctrl');
    if (isShift) parts.add('shift');
    if (isAlt) parts.add('alt');

    final key = event.logicalKey;
    final label = _keyLabel(key);
    if (label == null) return null;
    if (!parts.any((p) => p == label)) parts.add(label);

    if (parts.length < 2) return null; // bare modifier-only presses ignored
    return parts.join('+');
  }

  static String? _keyLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyA) return 'a';
    if (key == LogicalKeyboardKey.keyB) return 'b';
    if (key == LogicalKeyboardKey.keyC) return 'c';
    if (key == LogicalKeyboardKey.keyD) return 'd';
    if (key == LogicalKeyboardKey.keyE) return 'e';
    if (key == LogicalKeyboardKey.keyF) return 'f';
    if (key == LogicalKeyboardKey.keyG) return 'g';
    if (key == LogicalKeyboardKey.keyH) return 'h';
    if (key == LogicalKeyboardKey.keyI) return 'i';
    if (key == LogicalKeyboardKey.keyJ) return 'j';
    if (key == LogicalKeyboardKey.keyK) return 'k';
    if (key == LogicalKeyboardKey.keyL) return 'l';
    if (key == LogicalKeyboardKey.keyM) return 'm';
    if (key == LogicalKeyboardKey.keyN) return 'n';
    if (key == LogicalKeyboardKey.keyO) return 'o';
    if (key == LogicalKeyboardKey.keyP) return 'p';
    if (key == LogicalKeyboardKey.keyQ) return 'q';
    if (key == LogicalKeyboardKey.keyR) return 'r';
    if (key == LogicalKeyboardKey.keyS) return 's';
    if (key == LogicalKeyboardKey.keyT) return 't';
    if (key == LogicalKeyboardKey.keyU) return 'u';
    if (key == LogicalKeyboardKey.keyV) return 'v';
    if (key == LogicalKeyboardKey.keyW) return 'w';
    if (key == LogicalKeyboardKey.keyX) return 'x';
    if (key == LogicalKeyboardKey.keyY) return 'y';
    if (key == LogicalKeyboardKey.keyZ) return 'z';
    if (key == LogicalKeyboardKey.comma) return ',';
    if (key == LogicalKeyboardKey.period) return '.';
    if (key == LogicalKeyboardKey.slash) return '/';
    if (key == LogicalKeyboardKey.bracketLeft) return '[';
    if (key == LogicalKeyboardKey.bracketRight) return ']';
    if (key == LogicalKeyboardKey.space) return 'space';
    if (key == LogicalKeyboardKey.f1) return 'f1';
    if (key == LogicalKeyboardKey.f2) return 'f2';
    if (key == LogicalKeyboardKey.escape) return 'escape';
    return null;
  }
}
