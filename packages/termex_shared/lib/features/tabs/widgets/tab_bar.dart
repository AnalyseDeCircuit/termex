import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../icons/termex_icons.dart';
import '../../server_list/models/server_dto.dart';
import '../../server_list/state/connection_provider.dart';
import '../../../terminal/broadcast_registry.dart';
import '../state/tab_controller.dart';
import 'tab_item.dart';
import 'new_tab_menu.dart';

// Reserved minimum width for the [+] tab-card slot (icon + paddings).
// We compute the tab strip width as (available - this) so [+] always
// stays visible regardless of how many tabs.
const double _kPlusButtonSlot = 36.0;

/// Horizontal tab bar at the top of the terminal area.
///
/// Reads [tabListProvider] and [activeTabIdProvider]. Tabs render at their
/// natural width up to `(available - [+] slot)`, so the [+] button sits
/// immediately after the last tab card. Tab overflow scrolls horizontally.
class TermexTabBar extends ConsumerStatefulWidget {
  /// Called when the user picks an SSH server from the dropdown.
  final void Function(ServerDto server)? onNewTab;

  /// Called when the user picks "Local Terminal" from the dropdown.
  final VoidCallback? onLocalTerminal;

  const TermexTabBar({super.key, this.onNewTab, this.onLocalTerminal});

  @override
  ConsumerState<TermexTabBar> createState() => _TermexTabBarState();
}

class _TermexTabBarState extends ConsumerState<TermexTabBar> {
  final ScrollController _scrollCtrl = ScrollController();
  OverlayEntry? _newTabMenuEntry;
  final LayerLink _plusLayerLink = LayerLink();

  @override
  void dispose() {
    _closeNewTabMenu();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _openNewTabMenu() {
    if (_newTabMenuEntry != null) {
      _closeNewTabMenu();
      return;
    }
    _newTabMenuEntry = OverlayEntry(
      builder: (ctx) => _NewTabMenuOverlay(
        layerLink: _plusLayerLink,
        onSelect: (server) {
          _closeNewTabMenu();
          widget.onNewTab?.call(server);
        },
        onLocalTerminal: () {
          _closeNewTabMenu();
          widget.onLocalTerminal?.call();
        },
        onDismiss: _closeNewTabMenu,
      ),
    );
    Overlay.of(context).insert(_newTabMenuEntry!);
  }

  void _closeNewTabMenu() {
    _newTabMenuEntry?.remove();
    _newTabMenuEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(tabListProvider);
    final activeId = ref.watch(activeTabIdProvider);
    final notifier = ref.read(tabListProvider.notifier);
    final activeNotifier = ref.read(activeTabIdProvider.notifier);

    return Container(
      height: 36,
      // No bottom border: the active TabItem paints its own 2px primary
      // underline (see tab_item.dart). A full-width strip across the bar
      // would conflict with that "selected-tab-only" indicator design.
      decoration: BoxDecoration(
        color: context.colors.backgroundPrimary,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab list — flex to fill, scroll horizontally when overflowing.
          // Using a `Flexible(SingleChildScrollView + Row)` rather than a
          // fixed-width SizedBox + ListView.builder so each tab card lays
          // out at its NATURAL width (TabItem clamps itself between 80 and
          // 200) and the [+] card sits immediately after the last tab,
          // independent of card content length.
          Flexible(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: TermexSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final tab in tabs) _buildTabCard(ref, tab, activeId, notifier, activeNotifier),
                ],
              ),
            ),
          ),
          // [+] new-tab "card" — styled to match the TabItem card metrics
          // (36px height, 4px gutters, hover background) so it visually
          // belongs to the tab strip rather than reading as a floating
          // icon button.
          CompositedTransformTarget(
            link: _plusLayerLink,
            child: _PlusTabCard(onTap: _openNewTabMenu),
          ),
        ],
      ),
    );
  }

  Widget _buildTabCard(
    WidgetRef ref,
    dynamic tab,
    String? activeId,
    dynamic notifier,
    dynamic activeNotifier,
  ) {
    final sid = ref.watch(
        connectionProvider(tab.id).select((s) => s.sessionId));
    final broadcast = ref.watch(broadcastRegistryProvider);
    final isBroadcasting =
        sid != null && broadcast.hasFanout && broadcast.isMember(sid);
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: TabItem(
        key: ValueKey(tab.id),
        title: tab.title,
        status: tab.status,
        isActive: tab.id == activeId,
        isBroadcasting: isBroadcasting,
        isPlayback: tab.isRecording,
        onTap: () => activeNotifier.state = tab.id,
        onClose: () {
          notifier.closeTab(tab.id);
          if (tab.id == activeId) {
            final tabsNow = ref.read(tabListProvider);
            final remaining =
                tabsNow.where((t) => t.id != tab.id).toList();
            activeNotifier.state =
                remaining.isEmpty ? null : remaining.last.id;
          }
        },
        onClone: () {
          notifier.cloneTab(tab.id);
        },
      ),
    );
  }
}

// ─── [+] tab-card ─────────────────────────────────────────────────────────────

/// Inert-by-default tab-shaped card hosting the [+] glyph, matching the
/// adjacent [TabItem] visual metrics (height 36, hover/idle background,
/// no active underline). Tapping opens the new-tab menu via [onTap].
class _PlusTabCard extends StatefulWidget {
  final VoidCallback onTap;
  const _PlusTabCard({required this.onTap});

  @override
  State<_PlusTabCard> createState() => _PlusTabCardState();
}

class _PlusTabCardState extends State<_PlusTabCard> {
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
          height: 36,
          width: _kPlusButtonSlot,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered
                ? context.colors.backgroundSecondary
                : const Color(0x00000000),
          ),
          child: TermexIconWidget(
            TermexIcons.add,
            size: 16,
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlay wrapper that positions NewTabMenu below the "+" button
// ---------------------------------------------------------------------------

class _NewTabMenuOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final void Function(ServerDto) onSelect;
  final VoidCallback onLocalTerminal;
  final VoidCallback onDismiss;

  const _NewTabMenuOverlay({
    required this.layerLink,
    required this.onSelect,
    required this.onLocalTerminal,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-screen dismiss layer.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        // Anchor dropdown to the [+] button's bottom-left edge.
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: NewTabMenu(
            onSelect: onSelect,
            onLocalTerminal: onLocalTerminal,
            onDismiss: onDismiss,
          ),
        ),
      ],
    );
  }
}
