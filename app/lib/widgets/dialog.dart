import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../design/radius.dart';
import '../design/spacing.dart';
import 'button.dart';

enum DialogSize { small, medium, large }

double _dialogWidth(DialogSize size) => switch (size) {
      DialogSize.small => 400,
      DialogSize.medium => 560,
      DialogSize.large => 720,
    };

Future<T?> showTermexDialog<T>({
  required BuildContext context,
  required String title,
  required Widget body,
  List<Widget>? actions,
  DialogSize size = DialogSize.medium,
  bool barrierDismissible = true,
}) async {
  return _TermexDialogRoute<T>(
    context: context,
    title: title,
    body: body,
    actions: actions,
    size: size,
    barrierDismissible: barrierDismissible,
  ).push();
}

Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  bool destructive = false,
  DialogSize size = DialogSize.small,
}) async {
  return showTermexDialog<bool>(
    context: context,
    title: title,
    size: size,
    body: Text(
      message,
      style: TermexTypography.body.copyWith(color: TermexColors.textSecondary),
    ),
    actions: [
      Builder(
        builder: (ctx) => TermexButton(
          label: cancelLabel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
        ),
      ),
      Builder(
        builder: (ctx) => TermexButton(
          label: confirmLabel,
          variant: destructive ? ButtonVariant.danger : ButtonVariant.primary,
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
        ),
      ),
    ],
  );
}

class _TermexDialogRoute<T> {
  final BuildContext context;
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final DialogSize size;
  final bool barrierDismissible;

  _TermexDialogRoute({
    required this.context,
    required this.title,
    required this.body,
    this.actions,
    required this.size,
    required this.barrierDismissible,
  });

  Future<T?> push() {
    return Navigator.of(context, rootNavigator: true).push<T>(
      _TermexDialogPageRoute<T>(
        title: title,
        body: body,
        actions: actions,
        size: size,
        barrierDismissible: barrierDismissible,
      ),
    );
  }
}

class _TermexDialogPageRoute<T> extends PageRoute<T> {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final DialogSize size;

  _TermexDialogPageRoute({
    required this.title,
    required this.body,
    this.actions,
    required this.size,
    super.barrierDismissible,
  });

  @override
  Color get barrierColor => const Color(0x80000000);

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _TermexDialogShell(
      title: title,
      body: body,
      actions: actions,
      size: size,
      animation: animation,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
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

class _TermexDialogShell extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final DialogSize size;
  final Animation<double> animation;

  const _TermexDialogShell({
    required this.title,
    required this.body,
    this.actions,
    required this.size,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Cubic(0.22, 1.0, 0.36, 1.0),
        reverseCurve: Curves.easeIn,
      ),
    );
    final width = _dialogWidth(size);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context, rootNavigator: true).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: ScaleTransition(
          scale: scaleAnim,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: TermexColors.backgroundSecondary,
                borderRadius: TermexRadius.lg,
                border: Border.all(color: TermexColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DialogHeader(
                    title: title,
                    onClose: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TermexSpacing.xl,
                        vertical: TermexSpacing.lg,
                      ),
                      child: body,
                    ),
                  ),
                  if (actions != null && actions!.isNotEmpty)
                    _DialogFooter(actions: actions!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _DialogHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.xl,
        vertical: TermexSpacing.lg,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TermexTypography.heading3.copyWith(
                color: TermexColors.textPrimary,
              ),
            ),
          ),
          _CloseButton(onTap: onClose),
        ],
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered
                ? TermexColors.backgroundTertiary
                : const Color(0x00000000),
            borderRadius: TermexRadius.sm,
          ),
          alignment: Alignment.center,
          child: Text(
            '×',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textSecondary,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  final List<Widget> actions;
  const _DialogFooter({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.xl,
        vertical: TermexSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: TermexSpacing.sm),
            actions[i],
          ],
        ],
      ),
    );
  }
}
