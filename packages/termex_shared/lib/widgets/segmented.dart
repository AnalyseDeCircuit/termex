import 'package:flutter/widgets.dart';
import '../design/colors.dart';
import '../design/radius.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import 'clickable.dart';

class TermexSegmented extends StatefulWidget {
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const TermexSegmented({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  State<TermexSegmented> createState() => _TermexSegmentedState();
}

class _TermexSegmentedState extends State<TermexSegmented>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  int _prevIndex = 0;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.selectedIndex;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(TermexSegmented old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _prevIndex = old.selectedIndex;
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    assert(count >= 2, 'TermexSegmented requires at least 2 items');

    return Semantics(
      label: 'Segmented control',
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: context.colors.backgroundTertiary,
          borderRadius: TermexRadius.md,
        ),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final itemWidth = constraints.maxWidth / count;

            return Stack(
              children: [
                // Sliding indicator
                AnimatedBuilder(
                  animation: _slideAnim,
                  builder: (_, __) {
                    final fromX = _prevIndex * itemWidth;
                    final toX = widget.selectedIndex * itemWidth;
                    final x = fromX + (toX - fromX) * _slideAnim.value;
                    return Positioned(
                      left: x + 2,
                      top: 2,
                      width: itemWidth - 4,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ctx.colors.backgroundSecondary,
                          borderRadius: TermexRadius.sm,
                          border: Border.all(color: ctx.colors.border),
                        ),
                      ),
                    );
                  },
                ),
                // Labels
                Row(
                  children: [
                    for (int i = 0; i < count; i++)
                      Expanded(
                        child: Clickable(
                          onTap: () => widget.onChanged(i),
                          behavior: HitTestBehavior.opaque,
                          child: Semantics(
                            button: true,
                            selected: widget.selectedIndex == i,
                            label: widget.items[i],
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: TermexSpacing.xs),
                                child: Text(
                                  widget.items[i],
                                  style: TermexTypography.bodySmall.copyWith(
                                    color: widget.selectedIndex == i
                                        ? ctx.colors.textPrimary
                                        : ctx.colors.textSecondary,
                                    fontWeight: widget.selectedIndex == i
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
