import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../icons/termex_icons.dart';
import '../../../widgets/button.dart';
import '../../server_list/models/server_dto.dart';
import '../state/tab_controller.dart';
import 'tab_item.dart';
import 'new_tab_menu.dart';

/// Horizontal tab bar at the top of the terminal area.
///
/// Reads [tabListProvider] and [activeTabIdProvider].  Supports scroll when
/// many tabs are open, plus a "+" button to open the new-tab menu.
class TermexTabBar extends ConsumerStatefulWidget {
  /// Called when the user wants to open a new tab from the menu.
  final void Function(ServerDto server)? onNewTab;

  const TermexTabBar({super.key, this.onNewTab});

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
      child: Row(
        children: [
          // Scrollable tab list
          Expanded(
            child: tabs.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    controller: _scrollCtrl,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: TermexSpacing.xs,
                      vertical: 2,
                    ),
                    itemCount: tabs.length,
                    itemBuilder: (ctx, i) {
                      final tab = tabs[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: TabItem(
                          key: ValueKey(tab.id),
                          title: tab.title,
                          status: tab.status,
                          isActive: tab.id == activeId,
                          onTap: () =>
                              activeNotifier.state = tab.id,
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
          // "+" new-tab button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TermexSpacing.xs,
              vertical: 4,
            ),
            child: CompositedTransformTarget(
              link: _plusLayerLink,
              child: TermexIconButton(
                icon: TermexIconWidget(TermexIcons.add, size: 16),
                size: ButtonSize.small,
                variant: ButtonVariant.ghost,
                tooltip: 'New Tab',
                onPressed: _openNewTabMenu,
              ),
            ),
          ),
        ],
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
  final VoidCallback onDismiss;

  const _NewTabMenuOverlay({
    required this.layerLink,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: layerLink,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 4),
      child: Align(
        alignment: Alignment.topRight,
        child: NewTabMenu(
          onSelect: onSelect,
          onDismiss: onDismiss,
        ),
      ),
    );
  }
}
