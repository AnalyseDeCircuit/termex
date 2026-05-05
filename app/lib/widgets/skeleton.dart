import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

class TermexSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const TermexSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<TermexSkeleton> createState() => _TermexSkeletonState();
}

class _TermexSkeletonState extends State<TermexSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height ?? 16,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? TermexRadius.sm,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value.clamp(0.0, 1.0),
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: const [
                TermexColors.backgroundSecondary,
                TermexColors.backgroundTertiary,
                TermexColors.backgroundSecondary,
              ],
            ),
          ),
        );
      },
    );
  }
}

class TermexSkeletonText extends StatelessWidget {
  final int lines;
  final double lineHeight;

  const TermexSkeletonText({
    super.key,
    this.lines = 3,
    this.lineHeight = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines; i++) ...[
          TermexSkeleton(
            height: lineHeight,
            width: i == lines - 1 ? null : double.infinity,
          ),
          if (i < lines - 1) const SizedBox(height: TermexSpacing.sm),
        ],
      ],
    );
  }
}
