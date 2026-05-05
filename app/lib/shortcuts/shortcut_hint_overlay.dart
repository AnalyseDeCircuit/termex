/// Shortcut hint overlay shown when Cmd/Ctrl is held for 1 second (v0.48 §4.4).
library;

import 'dart:async';

import 'package:flutter/material.dart' hide ShortcutRegistry;
import 'package:flutter/services.dart';

import 'shortcut_registry.dart';
import 'shortcut_scope.dart';

class ShortcutHintOverlay extends StatefulWidget {
  final ShortcutScope scope;
  final Widget child;

  const ShortcutHintOverlay({
    super.key,
    required this.scope,
    required this.child,
  });

  @override
  State<ShortcutHintOverlay> createState() => _ShortcutHintOverlayState();
}

class _ShortcutHintOverlayState extends State<ShortcutHintOverlay> {
  bool _visible = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onKeyDown(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final isMod = key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight;
    if (!isMod) return;
    _timer ??= Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  void _onKeyUp(KeyEvent event) {
    if (event is! KeyUpEvent) return;
    final key = event.logicalKey;
    final isMod = key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight;
    if (!isMod) return;
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (e) {
        _onKeyDown(e);
        _onKeyUp(e);
      },
      child: Stack(
        children: [
          widget.child,
          if (_visible) _HintPanel(scope: widget.scope),
        ],
      ),
    );
  }
}

class _HintPanel extends StatelessWidget {
  final ShortcutScope scope;

  const _HintPanel({required this.scope});

  @override
  Widget build(BuildContext context) {
    final bindings = ShortcutRegistry.instance
        .forScope(scope)
        .where((b) => b.description != null)
        .toList();

    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xEE1E1E2E),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前可用快捷键',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 24,
                  runSpacing: 6,
                  children: bindings
                      .map((b) => _HintItem(
                          combo: b.combo.raw,
                          description: b.description!))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HintItem extends StatelessWidget {
  final String combo;
  final String description;

  const _HintItem({required this.combo, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            combo,
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(width: 6),
        Text(description,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
