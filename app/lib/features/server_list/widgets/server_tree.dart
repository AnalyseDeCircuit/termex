import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../design/spacing.dart';
import '../models/server_dto.dart';
import '../models/group_dto.dart';
import '../state/server_provider.dart';
import '../state/group_provider.dart';
import 'server_tree_node.dart';
import 'server_search_bar.dart';

/// The main sidebar server tree.
///
/// Reads from [serverListProvider] and [groupListProvider].
/// Supports group expand/collapse, selection, and double-tap to connect.
class ServerTree extends ConsumerStatefulWidget {
  /// Called with a server id when the user double-taps a server row.
  final void Function(String serverId)? onServerConnect;

  const ServerTree({super.key, this.onServerConnect});

  @override
  ConsumerState<ServerTree> createState() => _ServerTreeState();
}

class _ServerTreeState extends ConsumerState<ServerTree> {
  String? _selectedId;
  final Set<String> _expandedGroups = {};
  bool _autoExpandedOnce = false;
  String _query = '';

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
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TermexSpacing.sm,
            TermexSpacing.sm,
            TermexSpacing.sm,
            TermexSpacing.xs,
          ),
          child: ServerSearchBar(
            onChanged: (q) => setState(() => _query = q),
          ),
        ),
        Expanded(
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
                        depth: row.depth,
                        onTap: () => _select(s.id),
                        onDoubleTap: () => widget.onServerConnect?.call(s.id),
                      );
                    }
                  },
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
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: const AlwaysStoppedAnimation<Color>(TermexColors.primary),
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
