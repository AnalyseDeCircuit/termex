import 'package:flutter/widgets.dart';

// Slide + fade transition for page entry
class TermexSlideUpFadeTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const TermexSlideUpFadeTransition({super.key, required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
}

// Scale + fade for dialogs/popovers
class TermexScaleFadeTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final double beginScale;
  const TermexScaleFadeTransition({super.key, required this.animation, required this.child, this.beginScale = 0.92});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: beginScale, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart)),
        child: child,
      ),
    );
  }
}

// Stagger list animation helper
class StaggeredListAnimation extends StatelessWidget {
  final int index;
  final Animation<double> parent;
  final Widget child;
  final Duration itemDuration;

  const StaggeredListAnimation({
    super.key,
    required this.index,
    required this.parent,
    required this.child,
    this.itemDuration = const Duration(milliseconds: 150),
  });

  @override
  Widget build(BuildContext context) {
    final double startInterval = (index * 0.05).clamp(0.0, 0.8);
    final anim = CurvedAnimation(
      parent: parent,
      curve: Interval(startInterval, (startInterval + 0.3).clamp(0.0, 1.0), curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }
}
