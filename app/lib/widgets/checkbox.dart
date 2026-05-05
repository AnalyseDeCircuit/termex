import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

class TermexCheckbox extends StatefulWidget {
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final String? label;
  final bool disabled;
  final bool tristate;

  const TermexCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.disabled = false,
    this.tristate = false,
  });

  @override
  State<TermexCheckbox> createState() => _TermexCheckboxState();
}

class _TermexCheckboxState extends State<TermexCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scale;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.8),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 1.0),
        weight: 60,
      ),
    ]).animate(_scaleController);
  }

  @override
  void didUpdateWidget(TermexCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _scaleController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.disabled) return;
    if (widget.tristate) {
      if (widget.value == null) {
        widget.onChanged?.call(true);
      } else if (widget.value == true) {
        widget.onChanged?.call(false);
      } else {
        widget.onChanged?.call(null);
      }
    } else {
      widget.onChanged?.call(!(widget.value ?? false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChecked = widget.value == true;
    final isIndeterminate = widget.value == null;
    final filled = isChecked || isIndeterminate;

    Widget box = ScaleTransition(
      scale: _scale,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: filled ? TermexColors.primary : const Color(0x00000000),
          border: Border.all(
            color: filled
                ? TermexColors.primary
                : _focused
                    ? TermexColors.borderFocus
                    : TermexColors.border,
            width: _focused && !filled ? 2 : 1,
          ),
          borderRadius: TermexRadius.sm,
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: TermexColors.primary.withValues(alpha: 0.3),
                    blurRadius: 0,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: filled
            ? CustomPaint(
                painter: _BoxMarkPainter(indeterminate: isIndeterminate),
              )
            : null,
      ),
    );

    Widget content;
    if (widget.label != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          box,
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
      content = box;
    }

    if (widget.disabled) {
      content = Opacity(opacity: 0.4, child: content);
    }

    return Semantics(
      checked: isChecked,
      mixed: isIndeterminate,
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
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

class _BoxMarkPainter extends CustomPainter {
  final bool indeterminate;
  const _BoxMarkPainter({required this.indeterminate});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (indeterminate) {
      canvas.drawLine(
        Offset(size.width * 0.25, size.height * 0.5),
        Offset(size.width * 0.75, size.height * 0.5),
        paint,
      );
    } else {
      final path = Path()
        ..moveTo(size.width * 0.2, size.height * 0.5)
        ..lineTo(size.width * 0.45, size.height * 0.75)
        ..lineTo(size.width * 0.8, size.height * 0.25);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoxMarkPainter old) =>
      old.indeterminate != indeterminate;
}
