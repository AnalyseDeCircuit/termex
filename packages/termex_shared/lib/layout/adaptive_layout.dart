import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/breakpoints.dart';
import '../design/inherited_theme.dart';
import '../design/spacing.dart';
import '../design/theme.dart';
import '../design/typography.dart';

// Current layout mode derived from screen width.
enum LayoutMode { bottomBar, sidebar }

/// Returns the [LayoutMode] for a given logical pixel [width].
LayoutMode layoutModeFor(double width) =>
    width >= Breakpoints.sidebar ? LayoutMode.sidebar : LayoutMode.bottomBar;

/// Provider exposing the current [LayoutMode] based on the last known width.
/// Updated by [TermexAdaptiveLayout] on every rebuild.
final layoutModeProvider = StateProvider<LayoutMode>((ref) => LayoutMode.bottomBar);

/// Adapts between a sidebar + detail layout (≥900 px) and a bottom-bar layout
/// (< 900 px). Emits a [layoutModeProvider] update so child widgets can react
/// without reading [MediaQuery] directly.
///
/// Both [sidebarBuilder] and [bottomBarBuilder] are called lazily; only the
/// active layout is present in the widget tree.
class TermexAdaptiveLayout extends ConsumerWidget {
  final Widget Function(BuildContext) sidebarBuilder;
  final Widget Function(BuildContext) bottomBarBuilder;

  const TermexAdaptiveLayout({
    super.key,
    required this.sidebarBuilder,
    required this.bottomBarBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final mode = layoutModeFor(width);

    // Keep provider in sync without triggering a new frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(layoutModeProvider) != mode) {
        ref.read(layoutModeProvider.notifier).state = mode;
      }
    });

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey(mode),
        child: mode == LayoutMode.sidebar
            ? sidebarBuilder(context)
            : bottomBarBuilder(context),
      ),
    );
  }
}

// ─── iPad sidebar layout ──────────────────────────────────────────────────────

/// Full-screen sidebar + detail layout for iPad (≥900 px).
class SidebarDetailLayout extends StatelessWidget {
  final Widget sidebar;
  final Widget detail;

  /// Width of the fixed sidebar panel. Defaults to 280 px per design spec.
  final double sidebarWidth;

  const SidebarDetailLayout({
    super.key,
    required this.sidebar,
    required this.detail,
    this.sidebarWidth = 280,
  });

  @override
  Widget build(BuildContext context) {
    final theme = TermexThemeScope.of(context);
    return Row(
      children: [
        _SidebarPanel(width: sidebarWidth, theme: theme, child: sidebar),
        _SidebarDivider(color: theme.colors.border),
        Expanded(child: detail),
      ],
    );
  }
}

class _SidebarPanel extends StatelessWidget {
  final double width;
  final TermexThemeData theme;
  final Widget child;

  const _SidebarPanel({
    required this.width,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ColoredBox(
        color: theme.colors.backgroundSecondary,
        child: child,
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  final Color color;
  const _SidebarDivider({required this.color});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 1, child: ColoredBox(color: color));
}

// ─── Sidebar server list header ───────────────────────────────────────────────

/// Standard header used in the iPad sidebar above a server/team list.
class SidebarHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SidebarHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = TermexThemeScope.of(context);
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TermexTypography.heading4.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
