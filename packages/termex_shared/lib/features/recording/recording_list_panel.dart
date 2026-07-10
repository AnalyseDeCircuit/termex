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

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../icons/termex_icons.dart';
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
    try {
      await bridge.recordingDelete(id: id);
      if (!mounted) return;
      ToastController.success('已删除');
      _reload();
    } catch (e) {
      if (!mounted) return;
      ToastController.error('删除失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(onRefresh: _reload),
        Expanded(
          child: FutureBuilder<List<bridge.RecordingDto>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: TermexIconWidget(
                      TermexIcons.refresh,
                      size: 16,
                      color: TermexColors.textMuted,
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    '加载失败：${snap.error}',
                    style: TermexTypography.caption.copyWith(
                      color: TermexColors.danger,
                    ),
                  ),
                );
              }
              final recs = snap.data ?? const <bridge.RecordingDto>[];
              if (recs.isEmpty) {
                return _EmptyState();
              }
              // Group by serverName (fall back to "未关联服务器" when empty).
              final groups = <String, List<bridge.RecordingDto>>{};
              for (final r in recs) {
                final key = r.serverName.isEmpty ? '未关联服务器' : r.serverName;
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
                    onOpen: widget.onOpen,
                    onDelete: _delete,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  const _Header({required this.onRefresh});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.md,
          vertical: TermexSpacing.sm,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: TermexColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            const TermexIconWidget(
              TermexIcons.record,
              size: 14,
              color: TermexColors.textSecondary,
            ),
            const SizedBox(width: TermexSpacing.sm),
            Text(
              '会话录制',
              style: TermexTypography.bodySmall.copyWith(
                color: TermexColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onRefresh,
              child: const TermexIconWidget(
                TermexIcons.refresh,
                size: 12,
                color: TermexColors.textMuted,
              ),
            ),
          ],
        ),
      );
}

// ─── Empty state ──────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TermexIconWidget(
              TermexIcons.record,
              size: 36,
              color: TermexColors.textMuted,
            ),
            const SizedBox(height: TermexSpacing.sm),
            Text(
              '暂无录制',
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '在终端启用录制以收集会话回放',
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textMuted,
              ),
            ),
          ],
        ),
      );
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
              color: TermexColors.textMuted,
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onDoubleTap: () => widget.onOpen?.call(r.id, r.filePath),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TermexSpacing.md,
            vertical: TermexSpacing.xs,
          ),
          color: _hovered
              ? TermexColors.backgroundTertiary
              : const Color(0x00000000),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shortDate(r.startedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermexTypography.bodySmall.copyWith(
                        color: TermexColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_humanDuration(r.durationMs)} · ${r.eventCount} events'
                      '${r.autoRecorded ? " · auto" : ""}'
                      '${r.isEncrypted ? " · 🔒" : ""}',
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
                _IconBtn(
                  icon: TermexIcons.externalLink,
                  tooltip: '打开',
                  onTap: () => widget.onOpen?.call(r.id, r.filePath),
                ),
                const SizedBox(width: 4),
                _IconBtn(
                  icon: TermexIcons.delete,
                  tooltip: '删除',
                  color: TermexColors.danger,
                  onTap: widget.onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 20,
          height: 20,
          child: Center(
            child: TermexIconWidget(
              icon ?? TermexIcons.externalLink,
              size: 12,
              color: color ?? TermexColors.textSecondary,
            ),
          ),
        ),
      );
}
