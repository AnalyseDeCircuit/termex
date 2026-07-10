/// Lightweight sparkline painter for monitor metric history.
///
/// Renders a 0..1 normalised series as a filled line, no axes, no labels.
/// Designed to embed inside a 90×30 px metric card footer.
library;

import 'package:flutter/widgets.dart';

class Sparkline extends StatelessWidget {
  /// Values normalised to 0..1; null entries leave gaps.
  final List<double?> values;
  final Color color;
  final double height;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 30,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter(values, color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double?> values;
  final Color color;

  _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final stride = size.width / (values.length - 1);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true;

    final fill = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();
    final fillPath = Path();
    bool started = false;

    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        started = false;
        continue;
      }
      final x = i * stride;
      final y = size.height - v.clamp(0, 1) * size.height;
      if (!started) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      !identical(old.values, values) || old.color != color;
}
