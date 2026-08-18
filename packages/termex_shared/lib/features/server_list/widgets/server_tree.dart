import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;
import 'package:timeago/timeago.dart' as timeago;

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../design/spacing.dart';
import '../../../icons/termex_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/toast.dart';
import '../models/server_dto.dart';
import '../models/group_dto.dart';
import '../state/server_provider.dart';
import '../state/group_provider.dart';
import 'server_tree_node.dart';
import 'server_tree_context_menu.dart';
import 'server_form_dialog.dart';
import 'import_ssh_config_dialog.dart';
import 'server_search_bar.dart';

/// The main sidebar server tree.
///
/// Reads from [serverListProvider] and [groupListProvider].
/// Supports group expand/collapse, selection, and double-tap to connect.
class ServerTree extends ConsumerStatefulWidget {
  /// Called with a server id when the user double-taps a server row.
  final void Function(String serverId)? onServerConnect;

  /// Called when the user explicitly chooses "open SFTP" for a server
  /// (right-click menu or explicit action). Optional — DesktopShell wires
  /// this to open both a terminal tab and the SFTP panel.
  final void Function(String serverId)? onServerOpenSftp;

  const ServerTree({
    super.key,
    this.onServerConnect,
    this.onServerOpenSftp,
  });

  @override
  ConsumerState<ServerTree> createState() => _ServerTreeState();
}

class _ServerTreeState extends ConsumerState<ServerTree> {
  String? _selectedId;
  final Set<String> _expandedGroups = {};
  bool _autoExpandedOnce = false;
  String _query = '';
  OverlayEntry? _ctxMenuEntry;

  @override
  void dispose() {
    _closeCtxMenu();
    super.dispose();
  }

  void _closeCtxMenu() {
    _ctxMenuEntry?.remove();
    _ctxMenuEntry = null;
  }

  void _openContextMenu(ServerDto server, Offset globalPos) {
    _closeCtxMenu();
    final l10n = AppLocalizations.of(context);

    // A server received through team sync is read-only: it is owned by whoever
    // shared it. Duplicating into a private copy stays available, matching the
    // legacy sidebar.
    final isOwned = server.teamId == null;

    final groups = ref.read(groupListProvider).valueOrNull ?? const <GroupDto>[];
    final moveTargets = <ServerTreeMenuItem>[
      for (final g in groups.where((g) => g.id != server.groupId))
        ServerTreeMenuItem(
          icon: TermexIcons.folder,
          label: g.name,
          onSelect: () => _moveToGroup(server, g.id),
        ),
      if (server.groupId != null)
        ServerTreeMenuItem(
          divided: groups.any((g) => g.id != server.groupId),
          icon: TermexIcons.folderOpen,
          label: l10n.contextUngroup,
          onSelect: () => _moveToGroup(server, null),
        ),
    ];

    final items = <ServerTreeMenuItem>[
      ServerTreeMenuItem(
        icon: TermexIcons.connect,
        label: l10n.contextConnect,
        onSelect: () => widget.onServerConnect?.call(server.id),
      ),
      if (widget.onServerOpenSftp != null)
        ServerTreeMenuItem(
          icon: TermexIcons.sftp,
          label: l10n.sftpOpenSftp,
          onSelect: () => widget.onServerOpenSftp!(server.id),
        ),
      if (isOwned)
        ServerTreeMenuItem(
          divided: true,
          icon: TermexIcons.edit,
          label: l10n.contextEdit,
          onSelect: () => ServerFormDialog.show(context, editId: server.id),
        ),
      ServerTreeMenuItem(
        divided: !isOwned,
        icon: TermexIcons.copy,
        label: l10n.contextDuplicate,
        onSelect: () => _duplicate(server),
      ),
      if (isOwned)
        ServerTreeMenuItem(
          icon: TermexIcons.edit,
          label: l10n.contextRename,
          onSelect: () => _promptRename(server),
        ),
      if (isOwned && moveTargets.isNotEmpty)
        ServerTreeMenuItem(
          divided: true,
          icon: TermexIcons.folder,
          label: l10n.contextMoveTo,
          children: moveTargets,
        ),
      ServerTreeMenuItem(
        divided: true,
        // Lucide-style: a "plug" glyph as the active state, "unplug"
        // as the inverse. TermexIcons exposes them as connect/disconnect.
        icon: server.shared ? TermexIcons.disconnect : TermexIcons.connect,
        label: server.shared ? l10n.serverUnshareFromTeam : l10n.serverShareToTeam,
        onSelect: () => _toggleShare(server),
      ),
      ServerTreeMenuItem(
        divided: true,
        danger: true,
        icon: TermexIcons.delete,
        label: l10n.contextDelete,
        onSelect: () => _confirmDelete(server),
      ),
    ];
    final size = MediaQuery.sizeOf(context);
    _ctxMenuEntry = OverlayEntry(
      builder: (_) => ServerTreeContextMenu(
        position: globalPos,
        screenSize: size,
        items: items,
        onDismiss: _closeCtxMenu,
      ),
    );
    Overlay.of(context).insert(_ctxMenuEntry!);
  }

  /// Right-click on the blank area of the tree (not on a server row).
  /// Offers the root-level create/import actions that were previously
  /// only reachable from the "Termex ▾" dropdown — matching the legacy
  /// Tauri sidebar's empty-area context menu.
  void _openRootContextMenu(Offset globalPos) {
    _closeCtxMenu();
    final l10n = AppLocalizations.of(context);
    final items = <ServerTreeMenuItem>[
      ServerTreeMenuItem(
        icon: TermexIcons.add,
        label: l10n.sidebarNewConnection,
        onSelect: () => ServerFormDialog.show(context),
      ),
      ServerTreeMenuItem(
        icon: TermexIcons.folder,
        label: l10n.sidebarNewGroup,
        onSelect: _promptNewGroup,
      ),
      ServerTreeMenuItem(
        divided: true,
        icon: TermexIcons.download,
        label: l10n.sidebarImportSshConfig,
        onSelect: () => ImportSshConfigDialog.show(context),
      ),
      ServerTreeMenuItem(
        icon: TermexIcons.upload,
        label: l10n.backupExport,
        onSelect: _exportConfig,
      ),
    ];
    final size = MediaQuery.sizeOf(context);
    _ctxMenuEntry = OverlayEntry(
      builder: (_) => ServerTreeContextMenu(
        position: globalPos,
        screenSize: size,
        items: items,
        onDismiss: _closeCtxMenu,
      ),
    );
    Overlay.of(context).insert(_ctxMenuEntry!);
  }

  Future<void> _promptNewGroup() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TermexColors.backgroundSecondary,
        title: Text(l10n.sidebarNewGroup,
            style: const TextStyle(
                color: TermexColors.textPrimary, fontSize: 14)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: TermexColors.textPrimary),
          decoration: InputDecoration(hintText: l10n.sidebarGroupNameHint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(groupListProvider.notifier).createGroup(GroupInput(
            name: name.trim(),
            color: '#3B82F6',
            icon: 'folder',
            sortOrder: 0,
          ));
    }
  }

  /// Rebuilds the editable input from a stored server.
  ///
  /// [ServerDto] deliberately carries no secrets, so callers that need the
  /// copy to stay connectable must supply them separately.
  ServerInput _toInput(
    ServerDto s, {
    String? name,
    String? groupId,
    bool clearGroup = false,
    String? password,
    String? passphrase,
  }) {
    return ServerInput(
      name: name ?? s.name,
      host: s.host,
      port: s.port,
      username: s.username,
      authType: s.authType,
      password: password,
      passphrase: passphrase,
      keyPath: s.keyPath,
      groupId: clearGroup ? null : (groupId ?? s.groupId),
      tags: s.tags,
      tmuxMode: s.tmuxMode,
    );
  }

  /// Exports the encrypted config archive.
  ///
  /// Asks for a destination rather than writing a bare relative filename, which
  /// would land in the process working directory — on a packaged desktop build
  /// that is not anywhere the user can find.
  Future<void> _exportConfig() async {
    final l10n = AppLocalizations.of(context);

    final path = await FilePicker.platform.saveFile(
      dialogTitle: l10n.configExportTitle,
      fileName: 'termex-config.termex',
    );
    if (path == null) return;
    if (!mounted) return;

    final password = await _promptText(
      title: l10n.backupExport,
      hint: l10n.backupExportPasswordHint,
      obscure: true,
    );
    if (password == null || password.isEmpty) return;

    try {
      await bridge.settingsExport(path: path, password: password);
      ToastController.success(l10n.backupExportSuccess);
    } catch (e) {
      ToastController.error(l10n.serverActionFailed(l10n.backupExport, '$e'));
    }
  }

  /// Single-field prompt shared by rename and export.
  Future<String?> _promptText({
    required String title,
    required String hint,
    String initial = '',
    bool obscure = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TermexColors.backgroundSecondary,
        title: Text(title,
            style: const TextStyle(
                color: TermexColors.textPrimary, fontSize: 14)),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: obscure,
          style: const TextStyle(color: TermexColors.textPrimary),
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToGroup(ServerDto server, String? groupId) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(serverListProvider.notifier).moveToGroup(server.id, groupId);
    } catch (e) {
      ToastController.error(l10n.serverActionFailed(l10n.contextMoveTo, '$e'));
    }
  }

  /// Copies a server, secrets included.
  ///
  /// The credentials are read back from the keychain first: building the copy
  /// from the DTO alone would produce a server that looks complete but cannot
  /// authenticate, which is worse than no duplicate action at all.
  Future<void> _duplicate(ServerDto server) async {
    final l10n = AppLocalizations.of(context);
    try {
      String? password;
      String? passphrase;
      try {
        final creds = await bridge.getServerCredentials(id: server.id);
        password = creds.password;
        passphrase = creds.passphrase;
      } catch (_) {
        // Locked or unavailable keychain — copy the definition anyway rather
        // than failing outright; the user can re-enter the secret.
      }

      await ref.read(serverListProvider.notifier).createServer(
            _toInput(
              server,
              name: '${server.name} (copy)',
              password: password,
              passphrase: passphrase,
            ),
          );
    } catch (e) {
      ToastController.error(
          l10n.serverActionFailed(l10n.contextDuplicate, '$e'));
    }
  }

  Future<void> _promptRename(ServerDto server) async {
    final l10n = AppLocalizations.of(context);
    final name = await _promptText(
      title: l10n.contextRename,
      hint: l10n.contextRenameHint,
      initial: server.name,
    );

    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      // Distinguish "cleared the field" from "dismissed the dialog".
      if (name != null) ToastController.error(l10n.contextNameRequired);
      return;
    }
    if (trimmed == server.name) return;

    try {
      // Null secrets leave the keychain entries untouched; only the name
      // column changes.
      await ref
          .read(serverListProvider.notifier)
          .updateServer(server.id, _toInput(server, name: trimmed));
    } catch (e) {
      ToastController.error(l10n.serverActionFailed(l10n.contextRename, '$e'));
    }
  }

  Future<void> _confirmDelete(ServerDto server) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TermexColors.backgroundSecondary,
        title: Text(l10n.contextDelete,
            style: const TextStyle(
                color: TermexColors.textPrimary, fontSize: 14)),
        content: Text(
          l10n.contextDeleteConfirm(server.name),
          style: const TextStyle(color: TermexColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete,
                style: const TextStyle(color: TermexColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(serverListProvider.notifier).deleteServer(server.id);
      if (_selectedId == server.id) setState(() => _selectedId = null);
    } catch (e) {
      ToastController.error(l10n.serverActionFailed(l10n.contextDelete, '$e'));
    }
  }

  Future<void> _toggleShare(ServerDto server) async {
    final l10n = AppLocalizations.of(context);
    try {
      if (server.shared) {
        await bridge.teamUnshareServer(serverId: server.id);
        ToastController.success(l10n.serverUnsharedFromTeamToast);
      } else {
        await bridge.teamShareServer(serverId: server.id);
        ToastController.success(l10n.serverSharedToTeam);
      }
      // Refresh server list to update badges.
      // ignore: unused_result
      ref.refresh(serverListProvider);
    } catch (e) {
      final action =
          server.shared ? l10n.serverUnshareAction : l10n.serverShareAction;
      ToastController.error(l10n.serverActionFailed(action, '$e'));
    }
  }

  // ---- helpers ----

  bool _serverMatchesQuery(ServerDto s) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return s.name.toLowerCase().contains(q) ||
        s.host.toLowerCase().contains(q) ||
        s.username.toLowerCase().contains(q) ||
        s.tags.any((t) => t.toLowerCase().contains(q));
  }

  String _relativeTime(String? iso) {
    if (iso == null) return '';
    try {
      return timeago.format(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }

  void _toggleGroup(String groupId) {
    setState(() {
      if (_expandedGroups.contains(groupId)) {
        _expandedGroups.remove(groupId);
      } else {
        _expandedGroups.add(groupId);
      }
    });
  }

  void _select(String id) => setState(() => _selectedId = id);

  // ---- build flat list ----

  List<_TreeRow> _buildRows(List<ServerDto> servers, List<GroupDto> groups) {
    final rows = <_TreeRow>[];
    final query = _query.toLowerCase();

    // Ungrouped servers first
    final ungrouped = servers.where((s) => s.groupId == null).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final s in ungrouped) {
      if (!_serverMatchesQuery(s)) continue;
      rows.add(_TreeRow.server(s, depth: 0));
    }

    // Groups
    final sortedGroups = [...groups]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Expand all groups once on first render so contents are visible.
    if (!_autoExpandedOnce && sortedGroups.isNotEmpty) {
      _autoExpandedOnce = true;
      _expandedGroups.addAll(sortedGroups.map((g) => g.id));
    }

    for (final g in sortedGroups) {
      final groupServers = servers.where((s) => s.groupId == g.id).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      // If searching, only include group when it has matching servers
      if (query.isNotEmpty) {
        final matchingServers =
            groupServers.where(_serverMatchesQuery).toList();
        if (matchingServers.isEmpty) continue;
        rows.add(_TreeRow.group(g, expanded: true));
        for (final s in matchingServers) {
          rows.add(_TreeRow.server(s, depth: 1));
        }
      } else {
        final isExpanded = _expandedGroups.contains(g.id);
        rows.add(_TreeRow.group(g, expanded: isExpanded));
        if (isExpanded) {
          for (final s in groupServers) {
            rows.add(_TreeRow.server(s, depth: 1));
          }
        }
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    // Dropping the field has to drop the filter with it, or hiding the search
    // would leave the list silently filtered with nothing on screen to explain
    // why entries are missing.
    ref.listen<bool>(serverSearchVisibleProvider, (_, visible) {
      if (!visible && _query.isNotEmpty) setState(() => _query = '');
    });

    final serversAsync = ref.watch(serverListProvider);
    final groupsAsync = ref.watch(groupListProvider);

    // Show loading while either is loading
    if (serversAsync.isLoading || groupsAsync.isLoading) {
      return const Center(child: _LoadingSpinner());
    }

    final servers = serversAsync.valueOrNull ?? const [];
    final groups = groupsAsync.valueOrNull ?? const [];
    final rows = _buildRows(servers, groups);

    return Column(
      children: [
        // Only present once the header's search toggle is on — the field used
        // to sit here permanently, which made a short server list look busier
        // than it is.
        if (ref.watch(serverSearchVisibleProvider))
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TermexSpacing.sm,
              TermexSpacing.sm,
              TermexSpacing.sm,
              TermexSpacing.xs,
            ),
            child: ServerSearchBar(
              autofocus: true,
              onChanged: (q) => setState(() => _query = q),
            ),
          ),
        Expanded(
          // Blank-area right-click → root context menu. A server row's own
          // GestureDetector wins the gesture arena for taps landing on a
          // row, so this only fires on empty space / the empty-state view.
          // HitTestBehavior.opaque makes the whole area (including gaps
          // below the last row) catch the secondary tap.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapUp: (d) => _openRootContextMenu(d.globalPosition),
            onLongPressStart: (d) => _openRootContextMenu(d.globalPosition),
            child: rows.isEmpty
                ? _EmptyState(isFiltered: _query.isNotEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TermexSpacing.xs,
                      vertical: TermexSpacing.xs,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (ctx, i) {
                    final row = rows[i];
                    if (row.isGroup) {
                      final g = row.group!;
                      return ServerTreeNode(
                        key: ValueKey('group-${g.id}'),
                        isGroup: true,
                        id: g.id,
                        name: g.name,
                        isExpanded: row.expanded,
                        isSelected: _selectedId == g.id,
                        depth: 0,
                        onTap: () {
                          _select(g.id);
                          _toggleGroup(g.id);
                        },
                      );
                    } else {
                      final s = row.server!;
                      final relTime = _relativeTime(s.lastConnected);
                      return ServerTreeNode(
                        key: ValueKey('server-${s.id}'),
                        isGroup: false,
                        id: s.id,
                        name: s.name,
                        subtitle: '${s.username}@${s.host}:${s.port}',
                        lastConnected: relTime.isEmpty ? null : relTime,
                        isExpanded: false,
                        isSelected: _selectedId == s.id,
                        isConnected: false,
                        hasProxy: s.proxyId != null,
                        hasBastion: s.hasBastion,
                        isShared: s.shared,
                        depth: row.depth,
                        onTap: () => _select(s.id),
                        onDoubleTap: () => widget.onServerConnect?.call(s.id),
                        onContextMenu: (pos) => _openContextMenu(s, pos),
                      );
                    }
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Internal data class for flattened tree rows
// ---------------------------------------------------------------------------

class _TreeRow {
  final bool isGroup;
  final bool expanded;
  final GroupDto? group;
  final ServerDto? server;
  final int depth;

  const _TreeRow._({
    required this.isGroup,
    required this.expanded,
    this.group,
    this.server,
    required this.depth,
  });

  factory _TreeRow.group(GroupDto g, {required bool expanded}) => _TreeRow._(
        isGroup: true,
        expanded: expanded,
        group: g,
        depth: 0,
      );

  factory _TreeRow.server(ServerDto s, {required int depth}) => _TreeRow._(
        isGroup: false,
        expanded: false,
        server: s,
        depth: depth,
      );
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _LoadingSpinner extends StatelessWidget {
  const _LoadingSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(TermexColors.primary),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isFiltered;
  const _EmptyState({required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TermexSpacing.xl),
        child: Text(
          isFiltered ? 'No servers match your search.' : 'No servers yet.',
          style: TermexTypography.body.copyWith(
            color: TermexColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
