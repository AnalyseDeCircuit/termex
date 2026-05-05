import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

class AccordionItem {
  final String key;
  final String title;
  final Widget Function(BuildContext) contentBuilder;
  final Widget? leadingIcon;

  const AccordionItem({
    required this.key,
    required this.title,
    required this.contentBuilder,
    this.leadingIcon,
  });
}

class TermexAccordion extends StatefulWidget {
  final List<AccordionItem> items;
  final bool multiple;
  final Set<String>? initialOpenKeys;

  const TermexAccordion({
    super.key,
    required this.items,
    this.multiple = false,
    this.initialOpenKeys,
  });

  @override
  State<TermexAccordion> createState() => _TermexAccordionState();
}

class _TermexAccordionState extends State<TermexAccordion> {
  late Set<String> _openKeys;

  @override
  void initState() {
    super.initState();
    _openKeys = Set<String>.from(widget.initialOpenKeys ?? {});
  }

  void _toggle(String key) {
    setState(() {
      if (_openKeys.contains(key)) {
        _openKeys.remove(key);
      } else {
        if (!widget.multiple) {
          _openKeys.clear();
        }
        _openKeys.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.items.map((item) {
        final isOpen = _openKeys.contains(item.key);
        return _AccordionPanel(
          item: item,
          isOpen: isOpen,
          onToggle: () => _toggle(item.key),
        );
      }).toList(),
    );
  }
}

class _AccordionPanel extends StatefulWidget {
  final AccordionItem item;
  final bool isOpen;
  final VoidCallback onToggle;

  const _AccordionPanel({
    required this.item,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  State<_AccordionPanel> createState() => _AccordionPanelState();
}

class _AccordionPanelState extends State<_AccordionPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  late Animation<double> _arrowRotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.isOpen ? 1.0 : 0.0,
    );
    _sizeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _arrowRotation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_AccordionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TermexColors.border, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggle,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TermexSpacing.md,
                  vertical: TermexSpacing.md,
                ),
                child: Row(
                  children: [
                    if (widget.item.leadingIcon != null) ...[
                      widget.item.leadingIcon!,
                      const SizedBox(width: TermexSpacing.sm),
                    ],
                    Expanded(
                      child: Text(
                        widget.item.title,
                        style: TermexTypography.body.copyWith(
                          color: TermexColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: _arrowRotation,
                      child: const _ChevronIcon(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.isOpen || _controller.value > 0.0)
            SizeTransition(
              sizeFactor: _sizeAnimation,
              axisAlignment: -1.0,
              child: Container(
                padding: const EdgeInsets.only(
                  left: TermexSpacing.md,
                  right: TermexSpacing.md,
                  bottom: TermexSpacing.md,
                ),
                child: widget.item.contentBuilder(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChevronIcon extends StatelessWidget {
  const _ChevronIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(12, 12),
      painter: _ChevronPainter(),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TermexColors.textSecondary
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.35)
      ..lineTo(size.width * 0.5, size.height * 0.65)
      ..lineTo(size.width * 0.8, size.height * 0.35);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
