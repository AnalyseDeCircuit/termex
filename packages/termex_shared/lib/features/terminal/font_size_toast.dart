import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../design/colors.dart';
import '../../design/radius.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../platform/haptics.dart';

/// Terminal font size limits for Pinch-to-Zoom (design spec §3.1).
const double kFontSizeMin = 8.0;
const double kFontSizeMax = 28.0;
const double kFontSizeDefault = 14.0;

/// Clamps [size] to [kFontSizeMin]..[kFontSizeMax].
/// Calls [Haptics.zoomBound] when the value hits a boundary.
Future<double> clampFontSize(double size) async {
  if (size <= kFontSizeMin) {
    await Haptics.zoomBound();
    return kFontSizeMin;
  }
  if (size >= kFontSizeMax) {
    await Haptics.zoomBound();
    return kFontSizeMax;
  }
  return size;
}

/// Overlay bubble that appears briefly when the user pinches to resize the
/// terminal font. Shows "字号 {size}px" and auto-hides after [duration].
class FontSizeToast extends StatefulWidget {
  final double fontSize;
  final Duration duration;

  const FontSizeToast({
    super.key,
    required this.fontSize,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<FontSizeToast> createState() => _FontSizeToastState();
}

class _FontSizeToastState extends State<FontSizeToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(FontSizeToast old) {
    super.didUpdateWidget(old);
    if (old.fontSize != widget.fontSize) {
      _ctrl.forward(from: 0);
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(widget.duration, () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label =
        '字号 ${widget.fontSize.toStringAsFixed(0)}px';
    return FadeTransition(
      opacity: _opacity,
      child: Center(
        child: _ToastBubble(label: label),
      ),
    );
  }
}

class _ToastBubble extends StatelessWidget {
  final String label;
  const _ToastBubble({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TermexColors.backgroundPrimary.withValues(alpha: 0.85),
        borderRadius: TermexRadius.md,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.lg,
          vertical: TermexSpacing.sm,
        ),
        child: Text(
          label,
          style: TermexTypography.body.copyWith(
            color: TermexColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ─── Pinch-to-Zoom gesture wrapper ───────────────────────────────────────────

/// Wraps [child] with a two-finger scale gesture that adjusts a font size
/// state via [onFontSizeChange]. Shows [FontSizeToast] while pinching.
///
/// Keeps the baseline scale so each new pinch starts from the current size.
class PinchZoomFontSize extends StatefulWidget {
  final double fontSize;
  final ValueChanged<double> onFontSizeChange;
  final Widget child;

  const PinchZoomFontSize({
    super.key,
    required this.fontSize,
    required this.onFontSizeChange,
    required this.child,
  });

  @override
  State<PinchZoomFontSize> createState() => _PinchZoomFontSizeState();
}

class _PinchZoomFontSizeState extends State<PinchZoomFontSize> {
  double _baseSize = kFontSizeDefault;
  bool _active = false;
  double _currentSize = kFontSizeDefault;

  @override
  void initState() {
    super.initState();
    _baseSize = widget.fontSize;
    _currentSize = widget.fontSize;
  }

  @override
  void didUpdateWidget(PinchZoomFontSize old) {
    super.didUpdateWidget(old);
    if (!_active) {
      _baseSize = widget.fontSize;
      _currentSize = widget.fontSize;
    }
  }

  void _onScaleStart(ScaleStartDetails _) {
    _active = true;
    _baseSize = widget.fontSize;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Threshold 1.05× before recognising pinch (design spec §3.1).
    if (details.scale < 1.05 && details.scale > 1.0 / 1.05) return;
    final raw = (_baseSize * details.scale).clamp(kFontSizeMin, kFontSizeMax);
    if (raw != _currentSize) {
      setState(() => _currentSize = raw);
      widget.onFontSizeChange(raw);
      if (raw == kFontSizeMin || raw == kFontSizeMax) Haptics.zoomBound();
    }
  }

  void _onScaleEnd(ScaleEndDetails _) {
    _active = false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: Stack(
        children: [
          widget.child,
          if (_active)
            Positioned.fill(
              child: FontSizeToast(fontSize: _currentSize),
            ),
        ],
      ),
    );
  }
}
