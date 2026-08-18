import 'package:flutter/widgets.dart';
import '../design/colors.dart';
import '../design/radius.dart';
import '../design/spacing.dart';
import '../design/mobile_tokens.dart';

enum BottomSheetSnap { half, mid, full }

double _snapFraction(BottomSheetSnap snap) => switch (snap) {
      BottomSheetSnap.half => MobileTokens.bottomSheetSnapHalf,
      BottomSheetSnap.mid => MobileTokens.bottomSheetSnapMid,
      BottomSheetSnap.full => MobileTokens.bottomSheetSnapFull,
    };

Future<T?> showTermexBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  BottomSheetSnap initialSnap = BottomSheetSnap.mid,
  bool dismissible = true,
  String? semanticLabel,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    _BottomSheetRoute<T>(
      child: child,
      initialSnap: initialSnap,
      barrierDismissible: dismissible,
      semanticLabel: semanticLabel,
    ),
  );
}

class _BottomSheetRoute<T> extends PageRoute<T> {
  final Widget child;
  final BottomSheetSnap initialSnap;
  final String? semanticLabel;

  _BottomSheetRoute({
    required this.child,
    required this.initialSnap,
    required this.semanticLabel,
    super.barrierDismissible,
  });

  @override
  Color get barrierColor => const Color(0x80000000);

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return _BottomSheetShell<T>(
      animation: animation,
      initialSnap: initialSnap,
      semanticLabel: semanticLabel,
      child: child,
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
      child: child,
    );
  }
}

class _BottomSheetShell<T> extends StatefulWidget {
  final Widget child;
  final Animation<double> animation;
  final BottomSheetSnap initialSnap;
  final String? semanticLabel;

  const _BottomSheetShell({
    required this.child,
    required this.animation,
    required this.initialSnap,
    this.semanticLabel,
  });

  @override
  State<_BottomSheetShell<T>> createState() => _BottomSheetShellState<T>();
}

class _BottomSheetShellState<T> extends State<_BottomSheetShell<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _sheetCtrl;

  @override
  void initState() {
    super.initState();
    _sheetCtrl = AnimationController(
      vsync: this,
      value: _snapFraction(widget.initialSnap),
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 600) {
      Navigator.of(context, rootNavigator: true).pop();
      return;
    }
    final snaps = [
      MobileTokens.bottomSheetSnapHalf,
      MobileTokens.bottomSheetSnapMid,
      MobileTokens.bottomSheetSnapFull,
    ];
    final closest = snaps.reduce((a, b) =>
        (_sheetCtrl.value - a).abs() < (_sheetCtrl.value - b).abs() ? a : b);
    _sheetCtrl.animateTo(closest, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).pop(),
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          onVerticalDragUpdate: (d) {
            final delta = -d.primaryDelta! / screenHeight;
            _sheetCtrl.value =
                (_sheetCtrl.value + delta).clamp(0.05, MobileTokens.bottomSheetSnapFull);
          },
          onVerticalDragEnd: _onDragEnd,
          child: AnimatedBuilder(
            animation: _sheetCtrl,
            builder: (ctx, _) {
              final height = screenHeight * _sheetCtrl.value;
              return Semantics(
                label: widget.semanticLabel,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: widget.animation,
                    curve: const Cubic(0.22, 1.0, 0.36, 1.0),
                  )),
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: ctx.colors.backgroundSecondary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      border: Border(
                        top: BorderSide(color: ctx.colors.border),
                        left: BorderSide(color: ctx.colors.border),
                        right: BorderSide(color: ctx.colors.border),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _DragHandle(),
                        Expanded(child: widget.child),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TermexSpacing.sm),
      child: Center(
        child: Container(
          width: MobileTokens.dragHandleWidth,
          height: MobileTokens.dragHandleHeight,
          decoration: BoxDecoration(
            color: context.colors.border,
            borderRadius: TermexRadius.full,
          ),
        ),
      ),
    );
  }
}
