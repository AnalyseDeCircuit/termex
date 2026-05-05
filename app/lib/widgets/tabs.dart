import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../design/radius.dart';
import '../design/spacing.dart';

enum TabVariant { underline, pills, segmented }

@immutable
class TabItem {
  final String label;
  final Widget? icon;

  const TabItem({required this.label, this.icon});
}

class TermexTabs extends StatelessWidget {
  final List<TabItem> tabs;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final TabVariant variant;

  const TermexTabs({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onChanged,
    this.variant = TabVariant.underline,
  });

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      TabVariant.underline => _UnderlineTabs(
          tabs: tabs,
          activeIndex: activeIndex,
          onChanged: onChanged,
        ),
      TabVariant.pills => _PillsTabs(
          tabs: tabs,
          activeIndex: activeIndex,
          onChanged: onChanged,
        ),
      TabVariant.segmented => _SegmentedTabs(
          tabs: tabs,
          activeIndex: activeIndex,
          onChanged: onChanged,
        ),
    };
  }
}

class _UnderlineTabs extends StatelessWidget {
  final List<TabItem> tabs;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const _UnderlineTabs({
    required this.tabs,
    required this.activeIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < tabs.length; i++)
            _UnderlineTabItem(
              tab: tabs[i],
              isActive: i == activeIndex,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _UnderlineTabItem extends StatefulWidget {
  final TabItem tab;
  final bool isActive;
  final VoidCallback onTap;

  const _UnderlineTabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_UnderlineTabItem> createState() => _UnderlineTabItemState();
}

class _UnderlineTabItemState extends State<_UnderlineTabItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? TermexColors.textPrimary
        : _hovered
            ? TermexColors.textSecondary
            : TermexColors.textMuted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TermexSpacing.md,
            vertical: TermexSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.isActive
                    ? TermexColors.primary
                    : const Color(0x00000000),
                width: 2,
              ),
            ),
          ),
          child: _TabContent(tab: widget.tab, color: color),
        ),
      ),
    );
  }
}

class _PillsTabs extends StatelessWidget {
  final List<TabItem> tabs;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const _PillsTabs({
    required this.tabs,
    required this.activeIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: TermexSpacing.xs),
          _PillTabItem(
            tab: tabs[i],
            isActive: i == activeIndex,
            onTap: () => onChanged(i),
          ),
        ],
      ],
    );
  }
}

class _PillTabItem extends StatefulWidget {
  final TabItem tab;
  final bool isActive;
  final VoidCallback onTap;

  const _PillTabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_PillTabItem> createState() => _PillTabItemState();
}

class _PillTabItemState extends State<_PillTabItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0x00000000);
    if (widget.isActive) {
      bg = TermexColors.backgroundTertiary;
    } else if (_hovered) {
      bg = TermexColors.backgroundTertiary.withOpacity(0.5);
    }

    final textColor = widget.isActive
        ? TermexColors.textPrimary
        : TermexColors.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(
            horizontal: TermexSpacing.md,
            vertical: TermexSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: TermexRadius.md,
          ),
          child: _TabContent(tab: widget.tab, color: textColor),
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final List<TabItem> tabs;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({
    required this.tabs,
    required this.activeIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TermexColors.backgroundPrimary,
        borderRadius: TermexRadius.md,
        border: Border.all(color: TermexColors.border),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < tabs.length; i++)
            _SegmentedTabItem(
              tab: tabs[i],
              isActive: i == activeIndex,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _SegmentedTabItem extends StatefulWidget {
  final TabItem tab;
  final bool isActive;
  final VoidCallback onTap;

  const _SegmentedTabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SegmentedTabItem> createState() => _SegmentedTabItemState();
}

class _SegmentedTabItemState extends State<_SegmentedTabItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0x00000000);
    if (widget.isActive) {
      bg = TermexColors.backgroundSecondary;
    } else if (_hovered) {
      bg = TermexColors.backgroundTertiary.withOpacity(0.4);
    }

    final textColor = widget.isActive
        ? TermexColors.textPrimary
        : TermexColors.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(
            horizontal: TermexSpacing.md,
            vertical: TermexSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: TermexRadius.sm,
          ),
          child: _TabContent(tab: widget.tab, color: textColor),
        ),
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  final TabItem tab;
  final Color color;

  const _TabContent({required this.tab, required this.color});

  @override
  Widget build(BuildContext context) {
    if (tab.icon == null) {
      return Text(
        tab.label,
        style: TermexTypography.body.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tab.icon!,
        const SizedBox(width: TermexSpacing.xs),
        Text(
          tab.label,
          style: TermexTypography.body.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
