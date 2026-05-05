import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

enum LabelPosition { start, end }

class TermexToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final LabelPosition labelPosition;
  final bool disabled;

  const TermexToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.labelPosition = LabelPosition.end,
    this.disabled = false,
  });

  @override
  State<TermexToggle> createState() => _TermexToggleState();
}

class _TermexToggleState extends State<TermexToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _position;
  late Animation<Color?> _trackColor;
  late FocusNode _focusNode;

  static const _trackWidth = 32.0;
  static const _trackHeight = 18.0;
  static const _circleSize = 14.0;
  static const _padding = 2.0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: widget.value ? 1.0 : 0.0,
    );

    _position = Tween<double>(
      begin: _padding,
      end: _trackWidth - _circleSize - _padding,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Cubic(0.33, 1.0, 0.68, 1.0),
      ),
    );

    _trackColor = ColorTween(
      begin: const Color(0x00000000),
      end: TermexColors.primary,
    ).animate(_controller);
  }

  @override
  void didUpdateWidget(TermexToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.disabled) return;
    widget.onChanged?.call(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final track = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: _trackWidth,
          height: _trackHeight,
          decoration: BoxDecoration(
            color: _trackColor.value,
            borderRadius: TermexRadius.full,
            border: Border.all(
              color: widget.value
                  ? TermexColors.primary
                  : TermexColors.border,
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: _position.value,
                top: (_trackHeight - _circleSize) / 2,
                child: Container(
                  width: _circleSize,
                  height: _circleSize,
                  decoration: BoxDecoration(
                    color: widget.value
                        ? const Color(0xFFFFFFFF)
                        : TermexColors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    Widget content;
    if (widget.label != null) {
      final labelWidget = Text(
        widget.label!,
        style: TermexTypography.body.copyWith(
          color: widget.disabled
              ? TermexColors.textSecondary
              : TermexColors.textPrimary,
        ),
      );
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.labelPosition == LabelPosition.start
            ? [labelWidget, const SizedBox(width: TermexSpacing.sm), track]
            : [track, const SizedBox(width: TermexSpacing.sm), labelWidget],
      );
    } else {
      content = track;
    }

    if (widget.disabled) {
      content = Opacity(opacity: 0.4, child: content);
    }

    return Semantics(
      checked: widget.value,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.space) {
            _toggle();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: MouseRegion(
            cursor: widget.disabled
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click,
            child: content,
          ),
        ),
      ),
    );
  }
}
