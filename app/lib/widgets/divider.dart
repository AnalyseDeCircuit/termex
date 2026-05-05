import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

class TermexDivider extends StatelessWidget {
  final Axis direction;
  final double thickness;
  final Color? color;
  final double? indent;
  final double? endIndent;

  const TermexDivider({
    super.key,
    this.direction = Axis.horizontal,
    this.thickness = 1.0,
    this.color,
    this.indent,
    this.endIndent,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? TermexColors.border;

    if (direction == Axis.horizontal) {
      return Padding(
        padding: EdgeInsets.only(
          left: indent ?? 0,
          right: endIndent ?? 0,
        ),
        child: Container(
          height: thickness,
          width: double.infinity,
          color: effectiveColor,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: indent ?? 0,
        bottom: endIndent ?? 0,
      ),
      child: Container(
        width: thickness,
        height: double.infinity,
        color: effectiveColor,
      ),
    );
  }
}
