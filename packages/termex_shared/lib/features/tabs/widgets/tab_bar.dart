import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../icons/termex_icons.dart';
import '../../../widgets/button.dart';
import '../../server_list/models/server_dto.dart';
import '../../server_list/state/connection_provider.dart';
import '../../../terminal/broadcast_registry.dart';
import '../state/tab_controller.dart';
import 'tab_item.dart';
import 'new_tab_menu.dart';

// Natural per-tab width = TabItem container (120) + right padding (2)
// inside ListView.builder. Keep in sync with [TabItem]'s container width.
const double _kTabSlotWidth = 122.0;

// Total horizontal padding on the ListView (TermexSpacing.xs on each side,
// so 4 + 4 = 8). The list naturally fits `n * slotWidth + listPadding`.
const double _kTabListPadding = 8.0;

// Reserved minimum width for the [+] button slot (icon + padding).
const double _kPlusButtonSlot = 40.0;

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
      decoration: const BoxDecoration(
        color: TermexColors.backgroundPrimary,
        border: Border(
          bottom: BorderSide(color: TermexColors.border, width: 1),
        ),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        // Cap tab strip at (available width − [+] button slot) so the [+]
        // always sits right after the last tab card. When tab strip natural
        // width exceeds the cap, the strip scrolls horizontally.
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;
        final naturalTabsWidth =
            tabs.length * _kTabSlotWidth + _kTabListPadding;
        final maxTabsWidth = available.isFinite
            ? (available - _kPlusButtonSlot).clamp(0.0, double.infinity)
            : naturalTabsWidth;
        final tabsWidth = naturalTabsWidth < maxTabsWidth
            ? naturalTabsWidth
            : maxTabsWidth;

        return Row(
          children: [
            if (tabs.isNotEmpty)
              SizedBox(
                width: tabsWidth,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: TermexSpacing.xs,
                    vertical: 2,
                  ),
                  itemCount: tabs.length,
                  itemBuilder: (ctx, i) {
                    final tab = tabs[i];
                    final sid = ref.watch(
                        connectionProvider(tab.id).select((s) => s.sessionId));
                    final broadcast = ref.watch(broadcastRegistryProvider);
                    final isBroadcasting = sid != null &&
                        broadcast.hasFanout &&
                        broadcast.isMember(sid);
                    return Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: TabItem(
                        key: ValueKey(tab.id),
                        title: tab.title,
                        status: tab.status,
                        isActive: tab.id == activeId,
                        isBroadcasting: isBroadcasting,
                        onTap: () => activeNotifier.state = tab.id,
                        onClose: () {
                          notifier.closeTab(tab.id);
                          // If closing active tab, select neighbour
                          if (tab.id == activeId) {
                            final remaining = tabs
                                .where((t) => t.id != tab.id)
                                .toList();
                            activeNotifier.state = remaining.isEmpty
                                ? null
                                : remaining.last.id;
                          }
                        },
                        onClone: () {
                          notifier.cloneTab(tab.id);
                        },
                      ),
                    );
                  },
                ),
              ),
            // [+] Opens the new-tab menu (local terminal + recent servers).
            // Sits immediately after the last tab card.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TermexSpacing.xs,
                vertical: 4,
              ),
              child: CompositedTransformTarget(
                link: _plusLayerLink,
                child: TermexIconButton(
                  icon: const TermexIconWidget(TermexIcons.add, size: 16),
                  size: ButtonSize.small,
                  variant: ButtonVariant.ghost,
                  borderRadius: BorderRadius.zero,
                  tooltip: '新建标签',
                  onPressed: _openNewTabMenu,
                ),
              ),
            ),
          ],
        );
      }),
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
