import 'package:flutter/widgets.dart';
import '../design/colors.dart';
import '../design/mobile_tokens.dart';
import '../design/typography.dart';
import 'badge.dart';
import 'clickable.dart';

class BottomBarItem {
  final Widget icon;
  final Widget activeIcon;
  final String label;
  final int? badgeCount;
  final bool badgeDot;

  const BottomBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
    this.badgeDot = false,
  });
}

class TermexBottomBar extends StatefulWidget {
  final List<BottomBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const TermexBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  State<TermexBottomBar> createState() => _TermexBottomBarState();
}

class _TermexBottomBarState extends State<TermexBottomBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _indicatorCtrl;
  late Animation<double> _indicatorAnim;
  int _prevIndex = 0;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.selectedIndex;
    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _indicatorAnim = CurvedAnimation(
      parent: _indicatorCtrl,
      curve: Curves.easeOutCubic,
    );
    _indicatorCtrl.forward();
  }

  @override
  void didUpdateWidget(TermexBottomBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _prevIndex = old.selectedIndex;
      _indicatorCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.items.length;

    return Semantics(
      label: 'Bottom navigation bar',
      child: Container(
        height: MobileTokens.bottomBarHeight,
        decoration: const BoxDecoration(
          color: TermexColors.backgroundSecondary,
          border: Border(top: BorderSide(color: TermexColors.border)),
        ),
        child: Row(
          children: [
            for (int i = 0; i < itemCount; i++)
              Expanded(
                child: _BottomBarTab(
                  item: widget.items[i],
                  selected: widget.selectedIndex == i,
                  onTap: () => widget.onTap(i),
                  animation: widget.selectedIndex == i ? _indicatorAnim : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomBarTab extends StatelessWidget {
  final BottomBarItem item;
  final bool selected;
  final VoidCallback onTap;
  final Animation<double>? animation;

  const _BottomBarTab({
    required this.item,
    required this.selected,
    required this.onTap,
    this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? TermexColors.primary : TermexColors.textSecondary;
    final icon = selected ? item.activeIcon : item.icon;

    Widget iconWidget = ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: icon,
    );

    if (item.badgeCount != null || item.badgeDot) {
      iconWidget = TermexBadge(
        count: item.badgeCount,
        dot: item.badgeDot,
        child: iconWidget,
      );
    }

    Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 24, height: 24, child: iconWidget),
        const SizedBox(height: 2),
        Text(
          item.label,
          style: TermexTypography.caption.copyWith(
            color: color,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (selected && animation != null) {
      content = ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation!),
        child: content,
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Clickable(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: MobileTokens.bottomBarHeight,
          child: content,
        ),
      ),
    );
  }
}
