import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

class TermexSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String? label;
  final bool disabled;

  const TermexSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.onChanged,
    this.onChangeEnd,
    this.label,
    this.disabled = false,
  });

  @override
  State<TermexSlider> createState() => _TermexSliderState();
}

class _TermexSliderState extends State<TermexSlider> {
  bool _dragging = false;
  bool _hovered = false;

  double _snap(double raw) {
    if (widget.divisions == null || widget.divisions! <= 0) return raw;
    final step = (widget.max - widget.min) / widget.divisions!;
    final snapped = (raw / step).round() * step + widget.min;
    return snapped.clamp(widget.min, widget.max);
  }

  double _valueFromLocal(double localX, double trackWidth) {
    final ratio = (localX / trackWidth).clamp(0.0, 1.0);
    final raw = widget.min + ratio * (widget.max - widget.min);
    return _snap(raw);
  }

  @override
  Widget build(BuildContext context) {
    const trackHeight = 4.0;
    const thumbSize = 14.0;
    const thumbHoverSize = 18.0;
    const tooltipHeight = 28.0;

    final fraction = (widget.max > widget.min)
        ? ((widget.value - widget.min) / (widget.max - widget.min))
            .clamp(0.0, 1.0)
        : 0.0;

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final currentThumb = _hovered || _dragging ? thumbHoverSize : thumbSize;
        final thumbLeft =
            fraction * trackWidth - currentThumb / 2;

        return SizedBox(
          height: (_dragging && widget.label != null)
              ? tooltipHeight + 20 + currentThumb
              : currentThumb + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: (_dragging && widget.label != null)
                    ? tooltipHeight + 20 + (currentThumb - trackHeight) / 2
                    : (currentThumb + 8 - trackHeight) / 2,
                child: Container(
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: TermexColors.border,
                    borderRadius: TermexRadius.full,
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fraction,
                    child: Container(
                      decoration: BoxDecoration(
                        color: TermexColors.primary,
                        borderRadius: TermexRadius.full,
                      ),
                    ),
                  ),
                ),
              ),
              if (_dragging && widget.label != null)
                Positioned(
                  left: (thumbLeft + currentThumb / 2 - 30).clamp(
                      0, trackWidth - 60),
                  top: 0,
                  child: Container(
                    width: 60,
                    height: tooltipHeight,
                    decoration: BoxDecoration(
                      color: TermexColors.backgroundTertiary,
                      border: Border.all(color: TermexColors.border, width: 1),
                      borderRadius: TermexRadius.md,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.label!,
                      style: TermexTypography.caption.copyWith(
                        color: TermexColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: thumbLeft.clamp(0, trackWidth - currentThumb),
                top: (_dragging && widget.label != null)
                    ? tooltipHeight + 20
                    : (currentThumb + 8 - currentThumb) / 2,
                child: Container(
                  width: currentThumb,
                  height: currentThumb,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                    boxShadow: TermexElevation.e2,
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: widget.disabled
                      ? null
                      : (details) {
                          setState(() => _dragging = true);
                          final v = _valueFromLocal(
                              details.localPosition.dx, trackWidth);
                          widget.onChanged?.call(v);
                        },
                  onHorizontalDragUpdate: widget.disabled
                      ? null
                      : (details) {
                          final v = _valueFromLocal(
                              details.localPosition.dx, trackWidth);
                          widget.onChanged?.call(v);
                        },
                  onHorizontalDragEnd: widget.disabled
                      ? null
                      : (_) {
                          setState(() => _dragging = false);
                          widget.onChangeEnd?.call(widget.value);
                        },
                  onTapDown: widget.disabled
                      ? null
                      : (details) {
                          final v = _valueFromLocal(
                              details.localPosition.dx, trackWidth);
                          widget.onChanged?.call(v);
                        },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.disabled) {
      content = Opacity(opacity: 0.4, child: content);
    }

    return MouseRegion(
      onEnter: widget.disabled ? null : (_) => setState(() => _hovered = true),
      onExit: widget.disabled ? null : (_) => setState(() => _hovered = false),
      cursor: widget.disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: content,
    );
  }
}
