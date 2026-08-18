/// Sidebar panel listing recorded SSH sessions, grouped by server.
///
/// Mirrors the Tauri/Vue `RecordingList.vue` sidebar entry. The recording
/// engine itself is wired via FRB (`bridge.recordingListFull` / Delete /
/// GetPath / Export) — this widget only renders + dispatches actions.
///
/// v0.77.0 PC final parity: restored to OSS termex_shared after v0.69
/// erroneously demoted it to a "Pro stub". `recording.rs` FRB is real
/// (not stubbed) so the panel is fully functional out of the box.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tabs/state/tab_controller.dart' show tabListProvider;

import '../server_list/widgets/server_search_bar.dart';
import '../sidebar_search.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../icons/termex_icons.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/clickable.dart';
import '../../widgets/menu.dart';
import '../../widgets/panel_context_menu.dart';
import '../../widgets/toast.dart';

class RecordingListPanel extends ConsumerStatefulWidget {
  /// Optional callback when the user double-clicks (or "open") a recording —
  /// the host can route this to a player widget. When null, the panel
  /// just exposes the file path via copy-to-clipboard toast.
  final void Function(String recordingId, String filePath)? onOpen;

  const RecordingListPanel({super.key, this.onOpen});


  @override
  ConsumerState<RecordingListPanel> createState() => _RecordingListPanelState();
}

class _RecordingListPanelState extends ConsumerState<RecordingListPanel> {
  late Future<List<bridge.RecordingDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = bridge.recordingListFull();
  }

  void _reload() {
    setState(() => _future = bridge.recordingListFull());
  }

  Future<void> _delete(String id) async {
    final l10n = AppLocalizations.of(context);
    try {
      await bridge.recordingDelete(id: id);
      if (!mounted) return;
      ToastController.success(l10n.recordingDeleted);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ToastController.error(l10n.recordingDeleteFailed(e.toString()));
    }
  }

  /// Filter text. Local to the panel — recordings had no search before.
  String _query = '';

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      sidebarSearchVisibleProvider(SidebarSearchPanel.recordings),
      (_, visible) {
        // Hiding the field drops the filter too, so rows never stay missing
        // without a visible reason.
        if (!visible && _query.isNotEmpty) setState(() => _query = '');
      },
    );

    // The panel used to open with its own `_Header` row — a record icon, the
    // text "会话录制" and a refresh button. The host sidebar already draws a
    // section header with that exact title, so the title appeared twice and
    // the second row existed only to carry one button. Refresh moved to the
    // right-click menu (below), which lets the whole row go.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (d) => _showPanelMenu(context, d.globalPosition),
      child: Column(
      children: [
        if (ref.watch(
            sidebarSearchVisibleProvider(SidebarSearchPanel.recordings)))
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: ServerSearchBar(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        Expanded(
          child: FutureBuilder<List<bridge.RecordingDto>>(
            future: _future,
            builder: (ctx, snap) {
              final l10n = AppLocalizations.of(ctx);
              if (snap.connectionState != ConnectionState.done) {
                return Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: TermexIconWidget(
                      TermexIcons.refresh,
                      size: 16,
                      color: ctx.colors.textMuted,
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    l10n.commonLoadFailed('${snap.error}'),
                    style: TermexTypography.caption.copyWith(
                      color: ctx.colors.danger,
                    ),
                  ),
                );
              }
              final all = snap.data ?? const <bridge.RecordingDto>[];
              final q = _query.trim().toLowerCase();
              final recs = q.isEmpty
                  ? all
                  : all
                      .where((r) =>
                          r.serverName.toLowerCase().contains(q) ||
                          r.startedAt.toLowerCase().contains(q))
                      .toList(growable: false);
              if (recs.isEmpty) {
                return _EmptyState();
              }
              // Group by serverName (fall back to "未关联服务器" when empty).
              final groups = <String, List<bridge.RecordingDto>>{};
              for (final r in recs) {
                final key =
                    r.serverName.isEmpty ? l10n.recordingNoServer : r.serverName;
                groups.putIfAbsent(key, () => <bridge.RecordingDto>[]).add(r);
              }
              final entries = groups.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key));
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: entries.length,
                itemBuilder: (_, gi) {
                  final g = entries[gi];
                  return _GroupSection(
                    label: g.key,
                    rows: g.value,
                    // Defaults to the bundled player. The desktop sidebar
                    // constructs this panel without an onOpen, which left the
                    // open action — and the row's menu entry — inert.
                    // Opens in a tab rather than a modal: a replay is
                    // something to keep open beside the terminals it came
                    // from, and the tab strip marks it as playback.
                    onOpen: widget.onOpen ??
                        (id, filePath) =>
                            ref.read(tabListProvider.notifier).openRecordingTab(
                                  filePath,
                                  g.value
                                          .where((r) => r.id == id)
                                          .map((r) => r.serverName)
                                          .firstOrNull ??
                                      l10n.recordingTitle,
                                ),
                    onDelete: _delete,
                  );
                },
              );
            },
          ),
        ),
      ],
      ),
    );
  }

  /// Right-click menu for the panel, including its blank area — the
  /// `HitTestBehavior.opaque` on the wrapping detector is what makes empty
  /// space below the last row still respond.
  void _showPanelMenu(BuildContext context, Offset position) {
    final l10n = AppLocalizations.of(context);
    showContextMenu(
      context: context,
      position: position,
      items: [
        MenuItem(
          label: l10n.commonRefresh,
          icon: TermexIconWidget(
            TermexIcons.refresh,
            size: 13,
            color: context.colors.textSecondary,
          ),
          onSelected: _reload,
        ),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TermexIconWidget(
              TermexIcons.record,
              size: 36,
              color: context.colors.textMuted,
            ),
            const SizedBox(height: TermexSpacing.sm),
            Text(
              l10n.recordingEmpty,
              style: TermexTypography.caption.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.recordingEmptyHint,
              style: TermexTypography.caption.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ],
        ),
      );
  }
}

// ─── Group + rows ─────────────────────────────────────────────────────────

class _GroupSection extends StatelessWidget {
  final String label;
  final List<bridge.RecordingDto> rows;
  final void Function(String id, String filePath)? onOpen;
  final void Function(String id) onDelete;

  const _GroupSection({
    required this.label,
    required this.rows,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TermexSpacing.md,
            TermexSpacing.sm,
            TermexSpacing.md,
            4,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TermexTypography.caption.copyWith(
              color: context.colors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ...sorted.map(
          (r) => _Row(
            rec: r,
            onOpen: onOpen,
            onDelete: () => onDelete(r.id),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatefulWidget {
  final bridge.RecordingDto rec;
  final void Function(String id, String filePath)? onOpen;
  final VoidCallback onDelete;

  const _Row({required this.rec, required this.onOpen, required this.onDelete});

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  String _humanDuration(BigInt ms) {
    final s = (ms / BigInt.from(1000)).round();
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    if (m < 60) return '${m}m${s % 60}s';
    return '${m ~/ 60}h${m % 60}m';
  }

  String _shortDate(String iso) {
    if (iso.length < 16) return iso;
    return iso.substring(5, 16).replaceFirst('T', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rec;
    final l10n = AppLocalizations.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Clickable(
        onDoubleTap: () => widget.onOpen?.call(r.id, r.filePath),
        // Row menu. Consumes the gesture so the panel's blank-area menu
        // does not also fire. It matters more here than elsewhere: the
        // open/delete buttons only appear on hover, so without a menu
        // there is no affordance at all on a touch screen.
        onSecondaryTap: (pos) => _showRowMenu(context, pos),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TermexSpacing.md,
            vertical: TermexSpacing.xs,
          ),
          color: _hovered
              ? context.colors.backgroundTertiary
              : const Color(0x00000000),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _shortDate(r.startedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TermexTypography.bodySmall.copyWith(
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                        // Auto-started recordings were marked by an easily
                        // missed "· auto" in the metadata line; the Tauri list
                        // gave them a badge, which reads at a glance.
                        if (r.autoRecorded) ...[
                          const SizedBox(width: 6),
                          const _AutoBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_humanDuration(r.durationMs)} · ${r.eventCount} events'
                      '${r.isEncrypted ? " · 🔒" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermexTypography.caption.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hovered) ...[
                _IconBtn(
                  icon: TermexIcons.externalLink,
                  tooltip: l10n.recordingOpen,
                  onTap: () => widget.onOpen?.call(r.id, r.filePath),
                ),
                const SizedBox(width: 4),
                _IconBtn(
                  icon: TermexIcons.delete,
                  tooltip: l10n.commonDelete,
                  color: context.colors.danger,
                  onTap: widget.onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRowMenu(BuildContext context, Offset position) {
    final r = widget.rec;
    final l10n = AppLocalizations.of(context);
    showContextMenu(
      context: context,
      position: position,
      items: [
        MenuItem(
          label: l10n.recordingOpen,
          icon: menuIcon(context, TermexIcons.externalLink),
          // The host wires playback; with no handler the entry would do
          // nothing, so show it as unavailable instead.
          disabled: widget.onOpen == null,
          onSelected: widget.onOpen == null
              ? null
              : () => widget.onOpen!(r.id, r.filePath),
        ),
        MenuItem(
          label: l10n.ctxRecordingCopyPath,
          icon: menuIcon(context, TermexIcons.copy),
          onSelected: () {
            Clipboard.setData(ClipboardData(text: r.filePath));
            ToastController.success(l10n.ctxCopied);
          },
        ),
        const MenuItem.separator(),
        deleteMenuItem(
          context,
          label: l10n.commonDelete,
          onSelected: widget.onDelete,
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData? icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _IconBtn({
    this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Clickable(
        onTap: onTap,
        child: SizedBox(
          width: 20,
          height: 20,
          child: Center(
            child: TermexIconWidget(
              icon ?? TermexIcons.externalLink,
              size: 12,
              color: color ?? context.colors.textSecondary,
            ),
          ),
        ),
      );
}


/// Marks a recording that started automatically on connect, rather than from
/// the terminal's REC control. Amber, matching the Tauri list's badge.
class _AutoBadge extends StatelessWidget {
  const _AutoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: context.colors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        'AUTO',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: context.colors.warning,
        ),
      ),
    );
  }
}
