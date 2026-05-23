import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../design/tokens.dart';
import '../widgets/button.dart';
import '../widgets/badge.dart';
import '../widgets/card.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/bottom_sheet.dart';
import '../widgets/segmented.dart';
import '../widgets/skeleton.dart';

// Storybook-like component gallery. Only included in debug builds.
//
// Usage: push GalleryPage from a debug-only route or developer settings.

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    assert(kDebugMode, 'GalleryPage must only be used in debug builds');
    final theme = TermexThemeScope.of(context);
    return ColoredBox(
      color: theme.colors.background,
      child: ListView(
        padding: const EdgeInsets.all(TermexSpacing.lg),
        children: const [
          _SectionHeader('Buttons'),
          _ButtonSection(),
          _SectionHeader('Badges'),
          _BadgeSection(),
          _SectionHeader('Card'),
          _CardSection(),
          _SectionHeader('Segmented'),
          _SegmentedSection(),
          _SectionHeader('Bottom Bar'),
          _BottomBarSection(),
          _SectionHeader('Skeleton'),
          _SkeletonSection(),
          _SectionHeader('Bottom Sheet'),
          _BottomSheetSection(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = TermexThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: TermexSpacing.xl, bottom: TermexSpacing.sm),
      child: Text(
        title,
        style: theme.typography.heading3.copyWith(color: theme.colors.textPrimary),
      ),
    );
  }
}

class _ButtonSection extends StatelessWidget {
  const _ButtonSection();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TermexSpacing.sm,
      runSpacing: TermexSpacing.sm,
      children: [
        for (final v in ButtonVariant.values)
          TermexButton(label: v.name, variant: v),
        const TermexButton(label: 'Loading', loading: true),
        const TermexButton(label: 'Disabled', disabled: true),
      ],
    );
  }
}

class _BadgeSection extends StatelessWidget {
  const _BadgeSection();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: TermexSpacing.lg,
      runSpacing: TermexSpacing.lg,
      children: [
        TermexBadge(count: 3, child: _GalleryBox('count')),
        TermexBadge(count: 100, child: _GalleryBox('99+')),
        TermexBadge(dot: true, child: _GalleryBox('dot')),
      ],
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection();

  @override
  Widget build(BuildContext context) {
    final theme = TermexThemeScope.of(context);
    return TermexCard(
      child: Text('Card body', style: theme.typography.body.copyWith(color: theme.colors.textPrimary)),
    );
  }
}

class _SegmentedSection extends StatefulWidget {
  const _SegmentedSection();

  @override
  State<_SegmentedSection> createState() => _SegmentedSectionState();
}

class _SegmentedSectionState extends State<_SegmentedSection> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return TermexSegmented(
      items: const ['Terminal', 'Files', 'AI'],
      selectedIndex: _index,
      onChanged: (i) => setState(() => _index = i),
    );
  }
}

class _BottomBarSection extends StatefulWidget {
  const _BottomBarSection();

  @override
  State<_BottomBarSection> createState() => _BottomBarSectionState();
}

class _BottomBarSectionState extends State<_BottomBarSection> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return TermexBottomBar(
      selectedIndex: _index,
      onTap: (i) => setState(() => _index = i),
      items: const [
        BottomBarItem(
          icon: _GalleryBox('T'),
          activeIcon: _GalleryBox('T'),
          label: 'Terminal',
        ),
        BottomBarItem(
          icon: _GalleryBox('F'),
          activeIcon: _GalleryBox('F'),
          label: 'Files',
          badgeCount: 2,
        ),
        BottomBarItem(
          icon: _GalleryBox('A'),
          activeIcon: _GalleryBox('A'),
          label: 'AI',
        ),
        BottomBarItem(
          icon: _GalleryBox('S'),
          activeIcon: _GalleryBox('S'),
          label: 'Settings',
        ),
      ],
    );
  }
}

class _SkeletonSection extends StatelessWidget {
  const _SkeletonSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TermexSkeleton(width: 240, height: 16),
        SizedBox(height: TermexSpacing.sm),
        TermexSkeleton(width: 180, height: 16),
        SizedBox(height: TermexSpacing.sm),
        TermexSkeleton(width: double.infinity, height: 48),
      ],
    );
  }
}

class _BottomSheetSection extends StatelessWidget {
  const _BottomSheetSection();

  @override
  Widget build(BuildContext context) {
    return TermexButton(
      label: 'Show Bottom Sheet',
      onPressed: () => showTermexBottomSheet(
        context: context,
        child: const _SampleSheetContent(),
      ),
    );
  }
}

class _SampleSheetContent extends StatelessWidget {
  const _SampleSheetContent();

  @override
  Widget build(BuildContext context) {
    final theme = TermexThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(TermexSpacing.lg),
      child: Text(
        'Bottom sheet content',
        style: theme.typography.body.copyWith(color: theme.colors.textPrimary),
      ),
    );
  }
}

class _GalleryBox extends StatelessWidget {
  final String label;
  const _GalleryBox(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = TermexThemeScope.of(context);
    return Container(
      width: 32,
      height: 32,
      color: theme.colors.backgroundTertiary,
      alignment: Alignment.center,
      child: Text(label, style: theme.typography.caption.copyWith(color: theme.colors.textSecondary)),
    );
  }
}
