import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/tokens.dart';

/// A widget that captures a keyboard shortcut from the user.
///
/// Tapping enters "capture mode"; the next key combination pressed is recorded.
class KeybindingCapture extends StatefulWidget {
  final String currentValue;
  final void Function(String keyCombination) onCaptured;

  const KeybindingCapture({
    super.key,
    required this.currentValue,
    required this.onCaptured,
  });

  @override
  State<KeybindingCapture> createState() => _KeybindingCaptureState();
}

class _KeybindingCaptureState extends State<KeybindingCapture> {
  bool _capturing = false;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _startCapture() {
    setState(() => _capturing = true);
    _focus.requestFocus();
  }

  String _buildLabel(KeyEvent event) {
    final parts = <String>[];
    if (HardwareKeyboard.instance.isMetaPressed) parts.add('⌘');
    if (HardwareKeyboard.instance.isControlPressed) parts.add('Ctrl');
    if (HardwareKeyboard.instance.isAltPressed) parts.add('Alt');
    if (HardwareKeyboard.instance.isShiftPressed) parts.add('⇧');
    final key = event.logicalKey.keyLabel;
    if (key.isNotEmpty &&
        key != 'Meta' &&
        key != 'Control' &&
        key != 'Alt' &&
        key != 'Shift') {
      parts.add(key.toUpperCase());
    }
    return parts.join('');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _capturing ? null : _startCapture,
      child: KeyboardListener(
        focusNode: _focus,
        onKeyEvent: (event) {
          if (!_capturing) return;
          if (event is KeyDownEvent) {
            final label = _buildLabel(event);
            if (label.isNotEmpty && label.length > 1) {
              setState(() => _capturing = false);
              widget.onCaptured(label);
            }
          }
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            setState(() => _capturing = false);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _capturing
                ? TermexColors.primary.withOpacity(0.1)
                : TermexColors.backgroundTertiary,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: _capturing ? TermexColors.primary : TermexColors.border,
              width: _capturing ? 1.5 : 1,
            ),
          ),
          child: Text(
            _capturing ? '按下快捷键…' : widget.currentValue,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: _capturing
                  ? TermexColors.primary
                  : TermexColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
