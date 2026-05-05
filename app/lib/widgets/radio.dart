import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

class TermexRadio<T> extends StatefulWidget {
  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final String? label;
  final bool disabled;

  const TermexRadio({
    super.key,
    required this.value,
    required this.groupValue,
    this.onChanged,
    this.label,
    this.disabled = false,
  });

  @override
  State<TermexRadio<T>> createState() => _TermexRadioState<T>();
}

class _TermexRadioState<T> extends State<TermexRadio<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;
  late Animation<double> _dotScale;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: widget.value == widget.groupValue ? 1.0 : 0.0,
    );
    _dotScale = CurvedAnimation(
      parent: _dotController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void didUpdateWidget(TermexRadio<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isSelected = widget.value == widget.groupValue;
    final wasSelected = oldWidget.value == oldWidget.groupValue;
    if (isSelected != wasSelected) {
      if (isSelected) {
        _dotController.forward();
      } else {
        _dotController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  bool get _isSelected => widget.value == widget.groupValue;

  @override
  Widget build(BuildContext context) {
    Widget radio = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _isSelected ? TermexColors.primary : TermexColors.border,
          width: 1.5,
        ),
      ),
      child: Center(
        child: ScaleTransition(
          scale: _dotScale,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: TermexColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );

    Widget content;
    if (widget.label != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          radio,
          const SizedBox(width: TermexSpacing.sm),
          Text(
            widget.label!,
            style: TermexTypography.body.copyWith(
              color: widget.disabled
                  ? TermexColors.textSecondary
                  : TermexColors.textPrimary,
            ),
          ),
        ],
      );
    } else {
      content = radio;
    }

    if (widget.disabled) {
      content = Opacity(opacity: 0.4, child: content);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.disabled || widget.groupValue == widget.value
          ? null
          : () => widget.onChanged?.call(widget.value),
      child: MouseRegion(
        cursor: widget.disabled
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        child: content,
      ),
    );
  }
}
