import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';

enum LoadingVariant { spinner, overlay }

class TermexLoading extends StatefulWidget {
  final LoadingVariant variant;
  final double size;
  final Color? color;
  final String? message;

  const TermexLoading({
    super.key,
    this.variant = LoadingVariant.spinner,
    this.size = 24.0,
    this.color,
    this.message,
  });

  const TermexLoading.overlay({
    super.key,
    this.message,
    this.size = 36.0,
    this.color,
  }) : variant = LoadingVariant.overlay;

  @override
  State<TermexLoading> createState() => _TermexLoadingState();
}

class _TermexLoadingState extends State<TermexLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spinner = AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _SpinnerPainter(
          progress: _ctrl.value,
          color: widget.color ?? context.colors.primary,
          strokeWidth: widget.size * 0.1,
        ),
      ),
    );

    if (widget.variant == LoadingVariant.overlay) {
      return ColoredBox(
        color: const Color(0x80000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              spinner,
              if (widget.message != null) ...[
                const SizedBox(height: TermexSpacing.md),
                Text(
                  widget.message!,
                  style: TermexTypography.bodySmall.copyWith(
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (widget.message != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          spinner,
          const SizedBox(width: TermexSpacing.sm),
          Text(
            widget.message!,
            style: TermexTypography.bodySmall.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Semantics(label: '加载中', child: spinner);
  }
}

class _SpinnerPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _SpinnerPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Track arc (dim)
    final trackPaint = Paint()
      ..color = color.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc (bright)
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final startAngle = progress * 2 * math.pi - math.pi / 2;
    const sweepAngle = math.pi * 1.4;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.progress != progress || old.color != color;
}
