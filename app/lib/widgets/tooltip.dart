import 'dart:async';

import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../design/radius.dart';
import '../design/spacing.dart';
import '../design/elevation.dart';

enum TooltipPosition { top, bottom, left, right }

class TermexTooltip extends StatefulWidget {
  final Widget child;
  final String message;
  final TooltipPosition position;
  final Duration delay;

  const TermexTooltip({
    super.key,
    required this.child,
    required this.message,
    this.position = TooltipPosition.top,
    this.delay = const Duration(milliseconds: 500),
  });

  @override
  State<TermexTooltip> createState() => _TermexTooltipState();
}

class _TermexTooltipState extends State<TermexTooltip>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  Timer? _showTimer;
  OverlayEntry? _overlayEntry;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 80),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTooltip();
    _animCtrl.dispose();
    super.dispose();
  }

  void _scheduleShow() {
    _showTimer?.cancel();
    _showTimer = Timer(widget.delay, _showTooltip);
  }

  void _cancelAndHide() {
    _showTimer?.cancel();
    _showTimer = null;
    _hideTooltip();
  }

  void _showTooltip() {
    if (_overlayEntry != null) return;
    _overlayEntry = _buildEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _animCtrl.forward();
  }

  void _hideTooltip() {
    if (_overlayEntry == null) return;
    _animCtrl.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  Offset _calcOffset(Size tooltipSize) {
    const gap = 6.0;
    return switch (widget.position) {
      TooltipPosition.top =>
        Offset(-(tooltipSize.width / 2), -(tooltipSize.height + gap)),
      TooltipPosition.bottom => Offset(-(tooltipSize.width / 2), gap),
      TooltipPosition.left =>
        Offset(-(tooltipSize.width + gap), -(tooltipSize.height / 2)),
      TooltipPosition.right => Offset(gap, -(tooltipSize.height / 2)),
    };
  }

  OverlayEntry _buildEntry() {
    return OverlayEntry(
      builder: (ctx) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: _targetAnchor,
        followerAnchor: _followerAnchor,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: _TooltipBox(message: widget.message),
        ),
      ),
    );
  }

  Alignment get _targetAnchor => switch (widget.position) {
        TooltipPosition.top => Alignment.topCenter,
        TooltipPosition.bottom => Alignment.bottomCenter,
        TooltipPosition.left => Alignment.centerLeft,
        TooltipPosition.right => Alignment.centerRight,
      };

  Alignment get _followerAnchor => switch (widget.position) {
        TooltipPosition.top => Alignment.bottomCenter,
        TooltipPosition.bottom => Alignment.topCenter,
        TooltipPosition.left => Alignment.centerRight,
        TooltipPosition.right => Alignment.centerLeft,
      };

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _scheduleShow(),
        onExit: (_) => _cancelAndHide(),
        child: widget.child,
      ),
    );
  }
}

class _TooltipBox extends StatelessWidget {
  final String message;
  const _TooltipBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.sm,
        vertical: TermexSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: TermexRadius.md,
        border: Border.all(color: TermexColors.border),
        boxShadow: TermexElevation.e2,
      ),
      child: Text(
        message,
        style: TermexTypography.caption.copyWith(
          color: TermexColors.textPrimary,
        ),
      ),
    );
  }
}
