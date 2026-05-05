import 'dart:async';

import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../design/radius.dart';
import '../design/spacing.dart';
import '../design/elevation.dart';

enum ToastType { info, success, warning, error }

Color _toastAccent(ToastType type) => switch (type) {
      ToastType.info => TermexColors.primary,
      ToastType.success => TermexColors.success,
      ToastType.warning => TermexColors.warning,
      ToastType.error => TermexColors.danger,
    };

Duration _defaultDuration(ToastType type) =>
    type == ToastType.error ? const Duration(seconds: 5) : const Duration(seconds: 3);

@immutable
class _ToastData {
  final String id;
  final String message;
  final ToastType type;
  final Duration duration;

  const _ToastData({
    required this.id,
    required this.message,
    required this.type,
    required this.duration,
  });
}

final _toastKey = GlobalKey<_TermexToastOverlayState>();

abstract final class ToastController {
  static void show(
    String message, {
    ToastType type = ToastType.info,
    Duration? duration,
  }) {
    _toastKey.currentState?._addToast(_ToastData(
      id: UniqueKey().toString(),
      message: message,
      type: type,
      duration: duration ?? _defaultDuration(type),
    ));
  }

  static void info(String message, {Duration? duration}) =>
      show(message, type: ToastType.info, duration: duration);

  static void success(String message, {Duration? duration}) =>
      show(message, type: ToastType.success, duration: duration);

  static void warning(String message, {Duration? duration}) =>
      show(message, type: ToastType.warning, duration: duration);

  static void error(String message, {Duration? duration}) =>
      show(message, type: ToastType.error, duration: duration);
}

/// Wrap the root of the app with this widget to enable toasts.
/// [ToastController] will automatically find the nearest instance.
class TermexToastOverlay extends StatefulWidget {
  final Widget child;

  TermexToastOverlay({required this.child}) : super(key: _toastKey);

  @override
  State<TermexToastOverlay> createState() => _TermexToastOverlayState();
}

class _TermexToastOverlayState extends State<TermexToastOverlay> {
  final List<_ToastData> _toasts = [];

  void _addToast(_ToastData data) {
    setState(() => _toasts.add(data));
    Future.delayed(data.duration, () => _removeToast(data.id));
  }

  void _removeToast(String id) {
    if (!mounted) return;
    setState(() => _toasts.removeWhere((t) => t.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: TermexSpacing.xl,
          right: TermexSpacing.xl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _toasts.map((t) {
              return Padding(
                padding: const EdgeInsets.only(top: TermexSpacing.sm),
                child: _ToastItem(
                  key: ValueKey(t.id),
                  data: t,
                  onDismiss: () => _removeToast(t.id),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ToastItem extends StatefulWidget {
  final _ToastData data;
  final VoidCallback onDismiss;

  const _ToastItem({super.key, required this.data, required this.onDismiss});

  @override
  State<_ToastItem> createState() => _ToastItemState();
}

class _ToastItemState extends State<_ToastItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _toastAccent(widget.data.type);
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: TermexColors.backgroundSecondary,
              borderRadius: TermexRadius.md,
              border: Border.all(color: TermexColors.border),
              boxShadow: TermexElevation.e2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 3,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TermexSpacing.md,
                      vertical: TermexSpacing.sm,
                    ),
                    child: Text(
                      widget.data.message,
                      style: TermexTypography.body.copyWith(
                        color: TermexColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
