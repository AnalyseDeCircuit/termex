import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/tokens.dart';
import '../../../widgets/clickable.dart';

/// Captures a keyboard shortcut from the user.
///
/// State is owned by the parent (KeybindingsTab) so that only one row
/// can be in capture mode at any time — tapping a different row's
/// capture box switches the active row, automatically returning the
/// previous one to display mode. Tapping the same row again exits
/// capture without recording a new combination.
///
/// API:
///   * [currentValue] — the shortcut to render when not capturing
///   * [isCapturing] — parent-managed capture flag
///   * [onTap] — fires on every tap; parent toggles `isCapturing`
///   * [onCaptured] — fires when a non-modifier key is pressed while
///     capturing; parent should record the combo and unset `isCapturing`
///   * [onCaptureCancel] — fires on Escape; parent unsets `isCapturing`
class KeybindingCapture extends StatefulWidget {
  final String currentValue;
  final bool isCapturing;
  final VoidCallback onTap;
  final void Function(String keyCombination) onCaptured;
  final VoidCallback onCaptureCancel;

  const KeybindingCapture({
    super.key,
    required this.currentValue,
    required this.isCapturing,
    required this.onTap,
    required this.onCaptured,
    required this.onCaptureCancel,
  });

  @override
  State<KeybindingCapture> createState() => _KeybindingCaptureState();
}

class _KeybindingCaptureState extends State<KeybindingCapture> {
  final _focus = FocusNode();

  @override
  void didUpdateWidget(KeybindingCapture old) {
    super.didUpdateWidget(old);
    // When the parent flips us into capture mode, claim focus so the
    // KeyboardListener can receive events. When the parent flips us
    // back out, drop focus so other widgets (search box, etc.) can
    // keep working as expected.
    if (widget.isCapturing && !old.isCapturing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isCapturing) _focus.requestFocus();
      });
    } else if (!widget.isCapturing && old.isCapturing) {
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
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
    return Clickable(
      onTap: widget.onTap,
      child: KeyboardListener(
        focusNode: _focus,
        onKeyEvent: (event) {
          if (!widget.isCapturing) return;
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              widget.onCaptureCancel();
              return;
            }
            final label = _buildLabel(event);
            // Wait for at least one non-modifier key — modifier-only
            // combinations don't constitute a shortcut.
            if (label.isNotEmpty && label.length > 1) {
              widget.onCaptured(label);
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.isCapturing
                ? context.colors.primary.withValues(alpha: 0.1)
                : context.colors.backgroundTertiary,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: widget.isCapturing
                  ? context.colors.primary
                  : context.colors.border,
              width: widget.isCapturing ? 1.5 : 1,
            ),
          ),
          child: Text(
            widget.isCapturing ? '按下快捷键…' : widget.currentValue,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: widget.isCapturing
                  ? context.colors.primary
                  : context.colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
