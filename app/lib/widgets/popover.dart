import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../design/colors.dart';
import '../design/radius.dart';
import '../design/elevation.dart';

enum PopoverPosition { top, bottom, left, right }

class TermexPopover extends StatefulWidget {
  final Widget trigger;
  final Widget Function(VoidCallback close) content;
  final PopoverPosition position;
  final bool closeOnTapOutside;

  const TermexPopover({
    super.key,
    required this.trigger,
    required this.content,
    this.position = PopoverPosition.bottom,
    this.closeOnTapOutside = true,
  });

  @override
  State<TermexPopover> createState() => _TermexPopoverState();
}

class _TermexPopoverState extends State<TermexPopover>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _closePopover();
    _animCtrl.dispose();
    super.dispose();
  }

  void _togglePopover() {
    _isOpen ? _closePopover() : _openPopover();
  }

  void _openPopover() {
    if (_isOpen) return;
    setState(() => _isOpen = true);
    _overlayEntry = _buildEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _animCtrl.forward();
  }

  void _closePopover() {
    if (!_isOpen && _overlayEntry == null) return;
    setState(() => _isOpen = false);
    _animCtrl.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  Alignment get _targetAnchor => switch (widget.position) {
        PopoverPosition.top => Alignment.topCenter,
        PopoverPosition.bottom => Alignment.bottomCenter,
        PopoverPosition.left => Alignment.centerLeft,
        PopoverPosition.right => Alignment.centerRight,
      };

  Alignment get _followerAnchor => switch (widget.position) {
        PopoverPosition.top => Alignment.bottomCenter,
        PopoverPosition.bottom => Alignment.topCenter,
        PopoverPosition.left => Alignment.centerRight,
        PopoverPosition.right => Alignment.centerLeft,
      };

  Offset get _offset => switch (widget.position) {
        PopoverPosition.top => const Offset(0, -8),
        PopoverPosition.bottom => const Offset(0, 8),
        PopoverPosition.left => const Offset(-8, 0),
        PopoverPosition.right => const Offset(8, 0),
      };

  OverlayEntry _buildEntry() {
    return OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            if (widget.closeOnTapOutside)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _closePopover,
                ),
              ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: _targetAnchor,
              followerAnchor: _followerAnchor,
              offset: _offset,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Focus(
                    autofocus: true,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        _closePopover();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: _PopoverShell(
                      child: widget.content(_closePopover),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _togglePopover,
        child: widget.trigger,
      ),
    );
  }
}

class _PopoverShell extends StatelessWidget {
  final Widget child;
  const _PopoverShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: TermexRadius.lg,
        border: Border.all(color: TermexColors.border),
        boxShadow: TermexElevation.e2,
      ),
      child: child,
    );
  }
}
