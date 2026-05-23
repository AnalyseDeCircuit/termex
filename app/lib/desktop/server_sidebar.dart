import 'package:flutter/material.dart'
    show
        CircularProgressIndicator,
        ReorderableDelayedDragStartListener,
        ReorderableListView,
        Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/design/spacing.dart';
import 'package:termex_shared/design/typography.dart';
import 'package:termex_shared/icons/termex_icons.dart';
import 'package:termex_shared/widgets/button.dart';
import 'package:termex_shared/widgets/text_field.dart';
import 'package:termex_shared/features/server_list/models/server_dto.dart';
import 'package:termex_shared/features/server_list/state/server_provider.dart';
import 'package:termex_shared/features/server_list/widgets/server_form_dialog.dart';

/// Left sidebar showing the server list with search and add-server button.
class ServerSidebar extends ConsumerStatefulWidget {
  /// Called when user taps a server to open a terminal tab.
  final void Function(ServerDto server) onConnect;

  const ServerSidebar({super.key, required this.onConnect});

  @override
  ConsumerState<ServerSidebar> createState() => _ServerSidebarState();
}

class _ServerSidebarState extends ConsumerState<ServerSidebar> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddServer() {
    ServerFormDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(serverListProvider);

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(right: BorderSide(color: TermexColors.border)),
      ),
      child: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                TermexSpacing.sm, TermexSpacing.sm,
                TermexSpacing.sm, TermexSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: TermexTextField(
                    controller: _searchCtrl,
                    placeholder: 'Search servers…',
                    leadingIcon: const TermexIconWidget(TermexIcons.search, size: 14),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: TermexSpacing.xs),
                TermexIconButton(
                  icon: const TermexIconWidget(TermexIcons.add, size: 16),
                  size: ButtonSize.small,
                  variant: ButtonVariant.ghost,
                  tooltip: 'Add Server',
                  onPressed: _showAddServer,
                ),
              ],
            ),
          ),

          const _SidebarDivider(),

          // ── Server list ────────────────────────────────────────────────
          Expanded(
            child: servers.when(
              data: (list) {
                final filtered = _query.isEmpty
                    ? list
                    : list.where((s) =>
                        s.name
                            .toLowerCase()
                            .contains(_query.toLowerCase()) ||
                        s.host
                            .toLowerCase()
                            .contains(_query.toLowerCase())).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty ? 'No servers' : 'No results',
                      style: TermexTypography.bodySmall.copyWith(
                        color: TermexColors.textMuted,
                      ),
                    ),
                  );
                }

                // Reorder is only enabled for the unfiltered full list —
                // dragging within a search-filtered subset would be
                // ambiguous (gaps between filtered items have other servers
                // beneath them in the real ordering).
                final reorderable = _query.isEmpty;

                return ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: TermexSpacing.sm),
                  itemCount: filtered.length,
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) async {
                    if (!reorderable) return;
                    if (newIndex > oldIndex) newIndex -= 1;
                    final ids = filtered.map((s) => s.id).toList();
                    final moved = ids.removeAt(oldIndex);
                    ids.insert(newIndex, moved);
                    try {
                      await ref
                          .read(serverListProvider.notifier)
                          .reorder(ids);
                    } catch (_) {
                      // Notifier already refreshes from DB on failure.
                    }
                  },
                  itemBuilder: (_, i) {
                    final tile = _ServerTile(
                      server: filtered[i],
                      onConnect: () => widget.onConnect(filtered[i]),
                      onEdit: () => ServerFormDialog.show(
                        context,
                        editId: filtered[i].id,
                      ),
                      onDelete: () => ref
                          .read(serverListProvider.notifier)
                          .deleteServer(filtered[i].id),
                    );
                    if (!reorderable) {
                      return KeyedSubtree(
                        key: ValueKey(filtered[i].id),
                        child: tile,
                      );
                    }
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(filtered[i].id),
                      index: i,
                      child: tile,
                    );
                  },
                );
              },
              loading: () => const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: _Spinner(),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(TermexSpacing.md),
                child: Text(
                  e.toString(),
                  style: TermexTypography.bodySmall
                      .copyWith(color: TermexColors.danger),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Server tile ─────────────────────────────────────────────────────────────

class _ServerTile extends StatefulWidget {
  final ServerDto server;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServerTile({
    required this.server,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ServerTile> createState() => _ServerTileState();
}

class _ServerTileState extends State<_ServerTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onConnect,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.md),
          color: _hovered
              ? TermexColors.backgroundPrimary.withOpacity(0.6)
              : null,
          child: Row(
            children: [
              const TermexIconWidget(
                TermexIcons.server,
                size: 15,
                color: TermexColors.textSecondary,
              ),
              const SizedBox(width: TermexSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.server.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermexTypography.body.copyWith(
                        color: TermexColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${widget.server.username}@${widget.server.host}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermexTypography.caption.copyWith(
                        color: TermexColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hovered) ...[
                _TileIconButton(
                  icon: TermexIcons.edit,
                  tooltip: 'Edit',
                  onTap: widget.onEdit,
                ),
                const SizedBox(width: 2),
                _TileIconButton(
                  icon: TermexIcons.delete,
                  tooltip: 'Delete',
                  onTap: widget.onDelete,
                  danger: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TileIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  const _TileIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: TermexIconWidget(
          icon,
          size: 14,
          color: danger ? TermexColors.danger : TermexColors.textMuted,
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: TermexColors.border, child: SizedBox(height: 1));
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator(strokeWidth: 2);
  }
}
