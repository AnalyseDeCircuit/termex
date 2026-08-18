/// Mobile task history page (v0.79.24).
///
/// Reverse-chronological list of every [TaskEvent] the [TaskEventBus] has
/// ever seen during this app session. Built on top of `latestSnapshot` so
/// the same `taskId` only appears once (showing its most recent status).
///
/// Each row is tappable → pushes [MobileTaskDetailPage] for the full view.
/// Live-subscribes to [TaskEventBus.stream] so new tasks appear without a
/// manual refresh.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/design/spacing.dart';
import 'package:termex_shared/design/typography.dart';
import 'package:termex_shared/icons/termex_icons.dart';
import 'package:termex_shared/l10n/app_localizations.dart';
import 'package:termex_shared/widgets/clickable.dart';
import 'package:termex_shared/widgets/dialog.dart';
import 'package:termex_shared/widgets/text_field.dart';

import 'notification_threshold.dart';
import 'task_detail_page.dart';
import 'task_event_bus.dart';
import 'task_source.dart';
import 'text_highlight.dart';

class MobileTaskHistoryPage extends StatefulWidget {
  const MobileTaskHistoryPage({super.key});

  @override
  State<MobileTaskHistoryPage> createState() => _MobileTaskHistoryPageState();
}

class _MobileTaskHistoryPageState extends State<MobileTaskHistoryPage> {
  late List<TaskEvent> _items;
  StreamSubscription<void>? _sub;

  /// v0.79.35: filter chip state. null means "show all"; otherwise show
  /// only events whose [taskSourceOf] matches. Session-only — not
  /// persisted across launches (intentional: power users may scope
  /// to SFTP for one investigation then expect full visibility next
  /// session).
  TaskSource? _sourceFilter;

  /// v0.79.40: text search. Trimmed lowercase. Empty string = no
  /// filter. Combines with [_sourceFilter] via AND.
  ///
  /// v0.79.46: split into [_searchTokens] for multi-keyword OR matching.
  /// `_searchQuery` keeps the raw trimmed lowercased form for empty
  /// detection + simple equality checks; `_searchTokens` is the
  /// whitespace-split list each token must be non-empty.
  String _searchQuery = '';
  List<String> _searchTokens = const [];
  final TextEditingController _searchCtrl = TextEditingController();

  /// v0.79.32 + v0.79.33: snapshot of recently-deleted events pending
  /// undo. Single-delete stashes `{taskId: event}`; clear-all stashes the
  /// entire snapshot. Null when no undo banner is showing. On undo:
  /// cancel timer, `restoreAll(map)`, clear state. On timer fire / ✕:
  /// just clear state (the original `remove` / `clearAll` already took
  /// effect).
  Map<String, TaskEvent>? _pendingUndoMap;
  Timer? _pendingUndoTimer;

  /// v0.79.34: read from [NotificationThresholdConfig.current] at each
  /// delete so the window reflects the user's Settings choice. A delete
  /// in flight isn't shortened or extended mid-window — only the *next*
  /// delete picks up the new value.
  Duration get _undoWindow => Duration(
        seconds: NotificationThresholdConfig.current.undoWindowSeconds,
      );

  @override
  void initState() {
    super.initState();
    _items = _sortedSnapshot();
    // v0.79.27: listen on snapshotChanges so publish / remove / clearAll
    // all refresh the list uniformly. Avoids interpreting synthetic
    // TaskEvents on the main stream.
    _sub = TaskEventBus.instance.snapshotChanges.listen(_onSnapshotChange);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pendingUndoTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TaskEvent> _sortedSnapshot() {
    final snap = TaskEventBus.instance.latestSnapshot.values.toList();
    snap.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return snap;
  }

  /// The list that actually renders. `_items` stays as the
  /// full unsorted-by-filter snapshot so chip count labels stay accurate
  /// while the user toggles between categories.
  ///
  /// v0.79.40: AND-combines [_sourceFilter] (chip) and search.
  /// v0.79.46: search is multi-keyword OR — row matches if title or
  /// summary contains **any** token. AND between filter + search; OR
  /// within tokens.
  List<TaskEvent> get _filteredItems {
    final f = _sourceFilter;
    final tokens = _searchTokens;
    if (f == null && tokens.isEmpty) return _items;
    return _items.where((e) {
      if (f != null && taskSourceOf(e) != f) return false;
      if (tokens.isNotEmpty) {
        final title = e.title.toLowerCase();
        final summary = e.summary.toLowerCase();
        final hit = tokens.any(
            (t) => title.contains(t) || summary.contains(t));
        if (!hit) return false;
      }
      return true;
    }).toList();
  }

  /// Returns `{TaskSource: count}` for every bucket present + total
  /// under [TaskSource]-null sentinel.
  ({int total, int sftp, int ai, int other}) _counts() {
    var sftp = 0, ai = 0, other = 0;
    for (final e in _items) {
      switch (taskSourceOf(e)) {
        case TaskSource.sftp:
          sftp++;
          break;
        case TaskSource.ai:
          ai++;
          break;
        case TaskSource.other:
          other++;
          break;
      }
    }
    return (total: _items.length, sftp: sftp, ai: ai, other: other);
  }

  void _onSnapshotChange(void _) {
    if (!mounted) return;
    setState(() => _items = _sortedSnapshot());
  }

  /// v0.79.41: when chip / search filter is active, "clear all" scopes
  /// to the filtered subset instead of nuking the whole bus. Confirm
  /// dialog adapts its body text + count, and the undo banner shows the
  /// filtered count rather than total.
  bool get _filterActive =>
      _sourceFilter != null || _searchQuery.isNotEmpty;

  Future<void> _onClearAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    if (_filterActive) {
      await _clearFiltered(context, l10n);
    } else {
      await _clearEverything(context, l10n);
    }
  }

  Future<void> _clearEverything(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final count = _items.length;
    if (count == 0) return;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.taskHistoryClearAllConfirmTitle,
      message: l10n.taskHistoryClearAllConfirmBody(count),
      confirmLabel: l10n.taskHistoryActionClearAll,
      cancelLabel: l10n.commonCancel,
      destructive: true,
    );
    if (confirmed != true) return;
    // v0.79.33: stash the full snapshot before clearing so undo can
    // restore. Latest snapshot is the source of truth (covers any
    // events that arrived since _items was last sorted).
    final snapshot =
        Map<String, TaskEvent>.from(TaskEventBus.instance.latestSnapshot);
    _finalizePendingUndo();
    TaskEventBus.instance.clearAll();
    _stashUndo(snapshot);
  }

  Future<void> _clearFiltered(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final filtered = _filteredItems;
    final count = filtered.length;
    if (count == 0) return;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.taskHistoryClearFilteredConfirmTitle,
      message: l10n.taskHistoryClearFilteredConfirmBody(count),
      confirmLabel: l10n.taskHistoryActionClearFiltered,
      cancelLabel: l10n.commonCancel,
      destructive: true,
    );
    if (confirmed != true) return;
    _finalizePendingUndo();
    final removed = TaskEventBus.instance
        .removeMany(filtered.map((e) => e.taskId));
    _stashUndo(removed);
  }

  /// Common tail: post-clear, set up the undo banner with whatever was
  /// stashed (full snapshot for unscoped clear; filtered subset for
  /// scoped clear). Respects v0.79.34's "undo window = 0 → skip banner".
  void _stashUndo(Map<String, TaskEvent> snapshot) {
    if (!mounted || snapshot.isEmpty) return;
    final window = _undoWindow;
    if (window.inSeconds == 0) return;
    setState(() {
      _pendingUndoMap = snapshot;
      _pendingUndoTimer = Timer(window, _onUndoTimerFire);
    });
  }

  /// Confirm-only step. Returns whether the user accepted the deletion.
  /// Extracted in v0.79.39 so swipe + long-press paths can share the same
  /// confirmation prompt without duplicating the dialog wiring.
  Future<bool> _confirmDeleteOne(
    BuildContext context,
    TaskEvent event,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.taskHistoryDeleteConfirmTitle,
      message: l10n.taskHistoryDeleteConfirmBody(event.title),
      confirmLabel: l10n.taskHistoryActionDelete,
      cancelLabel: l10n.commonCancel,
      destructive: true,
    );
    return confirmed == true;
  }

  /// State-mutating half: removes from bus + starts undo timer. Assumes
  /// the caller already confirmed (either via dialog or Dismissible's
  /// confirmDismiss). Safe to call multiple times — re-staging the same
  /// taskId finalises the prior undo (per v0.79.32 single-undo invariant).
  void _performDeleteOne(TaskEvent event) {
    // v0.79.32: finalize the previous pending undo (if any) before
    // starting a new one — the user moved on, that opportunity is over.
    _finalizePendingUndo();
    TaskEventBus.instance.remove(event.taskId);
    if (!mounted) return;
    // v0.79.34: user disabled the undo window — skip banner entirely.
    final window = _undoWindow;
    if (window.inSeconds == 0) return;
    setState(() {
      _pendingUndoMap = {event.taskId: event};
      _pendingUndoTimer = Timer(window, _onUndoTimerFire);
    });
  }

  Future<void> _onDeleteOne(BuildContext context, TaskEvent event) async {
    if (!await _confirmDeleteOne(context, event)) return;
    _performDeleteOne(event);
  }

  void _onSearchChanged(String raw) {
    final q = raw.trim().toLowerCase();
    if (q == _searchQuery) return;
    // v0.79.46: also split into per-token list for OR matching. Skip
    // empty tokens — `"foo  bar"`.split(RegExp(' +')) handles repeated
    // spaces, but we additionally filter zero-length defensively.
    final tokens = q.isEmpty
        ? const <String>[]
        : q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    setState(() {
      _searchQuery = q;
      _searchTokens = tokens;
    });
  }

  void _onClearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _searchTokens = const [];
    });
  }

  void _onUndo() {
    final pending = _pendingUndoMap;
    if (pending == null) return;
    _pendingUndoTimer?.cancel();
    // restoreAll handles both 1-entry (single delete) and N-entry
    // (clearAll) cases uniformly. The bus's containsKey guard inside
    // each entry preserves race protection against newer arrivals.
    TaskEventBus.instance.restoreAll(pending);
    if (!mounted) return;
    setState(() {
      _pendingUndoMap = null;
      _pendingUndoTimer = null;
    });
  }

  void _onUndoTimerFire() {
    if (!mounted) return;
    setState(() {
      _pendingUndoMap = null;
      _pendingUndoTimer = null;
    });
  }

  void _onUndoDismiss() {
    _pendingUndoTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _pendingUndoMap = null;
      _pendingUndoTimer = null;
    });
  }

  /// Drop the pending undo without restoring — called when a *new*
  /// destructive action supersedes the prior one (only the most recent
  /// is undoable). The earlier removal is now permanent.
  void _finalizePendingUndo() {
    if (_pendingUndoMap == null) return;
    _pendingUndoTimer?.cancel();
    _pendingUndoMap = null;
    _pendingUndoTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = _filteredItems;
    final counts = _counts();
    return Container(
      color: TermexColors.backgroundPrimary,
      child: SafeArea(
        child: Column(
          children: [
            _Header(
              title: l10n.taskHistoryHeader,
              // v0.79.41: chip / search filter active → button text
              // narrows to "Clear filtered (N)"; otherwise the full
              // "Clear all". Hidden when nothing would be cleared.
              trailingLabel: _items.isEmpty
                  ? null
                  : _filterActive
                      ? (filtered.isEmpty
                          ? null
                          : l10n.taskHistoryActionClearFilteredWithCount(
                              filtered.length))
                      : l10n.taskHistoryActionClearAll,
              onTrailingTap: () => _onClearAll(context),
            ),
            if (_items.isNotEmpty) ...[
              _SearchBox(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                onClear: _onClearSearch,
                hasQuery: _searchQuery.isNotEmpty,
                placeholder: l10n.taskHistorySearchPlaceholder,
              ),
              _SourceFilterChips(
                selected: _sourceFilter,
                counts: counts,
                allLabel: l10n.taskHistoryFilterAll,
                sftpLabel: l10n.taskHistoryFilterSftp,
                aiLabel: l10n.taskHistoryFilterAi,
                otherLabel: l10n.taskHistoryFilterOther,
                onSelect: (source) =>
                    setState(() => _sourceFilter = source),
              ),
            ],
            Expanded(
              child: _items.isEmpty
                  ? _EmptyState(
                      title: l10n.taskHistoryEmptyTitle,
                      hint: l10n.taskHistoryEmptyHint,
                    )
                  : filtered.isEmpty
                      ? _EmptyState(
                          // v0.79.40: pick "no match for search" vs
                          // "no match for filter chip" hint based on
                          // which predicate is active. Search takes
                          // priority since it's the more-specific
                          // mismatch in the user's mental model.
                          title: _searchQuery.isNotEmpty
                              ? l10n.taskHistorySearchEmptyTitle
                              : l10n.taskHistoryFilterEmptyTitle,
                          hint: _searchQuery.isNotEmpty
                              ? l10n.taskHistorySearchEmptyHint
                              : l10n.taskHistoryFilterEmptyHint,
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final event = filtered[i];
                            return Dismissible(
                              key: ValueKey('task-row-${event.taskId}'),
                              direction: DismissDirection.endToStart,
                              background: const _SwipeDeleteBackground(),
                              confirmDismiss: (_) =>
                                  _confirmDeleteOne(context, event),
                              onDismissed: (_) => _performDeleteOne(event),
                              child: _TaskRow(
                                event: event,
                                highlightTokens: _searchTokens,
                                onLongPress: () =>
                                    _onDeleteOne(context, event),
                              ),
                            );
                          },
                        ),
            ),
            if (_pendingUndoMap != null)
              _UndoBanner(
                pending: _pendingUndoMap!,
                onUndo: _onUndo,
                onDismiss: _onUndoDismiss,
                deletedLabel: l10n.taskHistoryUndoDeleted,
                clearedLabel: l10n.taskHistoryUndoCleared(
                  _pendingUndoMap!.length,
                ),
                undoLabel: l10n.taskHistoryUndoAction,
              ),
          ],
        ),
      ),
    );
  }
}

/// v0.79.32: sticks at the bottom while the 5s undo window is open.
/// Reuses the same color palette as the BatteryBanner / settings page rows
/// for visual consistency — no extra design tokens introduced.
class _UndoBanner extends StatelessWidget {
  const _UndoBanner({
    required this.pending,
    required this.onUndo,
    required this.onDismiss,
    required this.deletedLabel,
    required this.clearedLabel,
    required this.undoLabel,
  });

  /// The set of events pending restore. Single-delete = 1 entry;
  /// clearAll = N entries. Used both for the visual label and to size
  /// the undo affordance.
  final Map<String, TaskEvent> pending;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;
  final String deletedLabel;
  final String clearedLabel;
  final String undoLabel;

  @override
  Widget build(BuildContext context) {
    final isBulk = pending.length > 1;
    final label = isBulk
        ? clearedLabel
        // Single delete: include the title for context. The bulk variant
        // uses a count-only label (clearedLabel is pre-formatted with N).
        : '$deletedLabel「${pending.values.first.title}」';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(top: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TermexTypography.body.copyWith(
                color: TermexColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: TermexSpacing.sm),
          Clickable(
            behavior: HitTestBehavior.opaque,
            onTap: onUndo,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                undoLabel,
                style: TermexTypography.body.copyWith(
                  color: TermexColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Clickable(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(
                TermexIcons.close,
                size: 16,
                color: TermexColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    this.trailingLabel,
    this.onTrailingTap,
  });
  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          Clickable(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                TermexIcons.close,
                size: 20,
                color: TermexColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: TermexTypography.body.copyWith(
                color: TermexColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailingLabel != null)
            Clickable(
              behavior: HitTestBehavior.opaque,
              onTap: onTrailingTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  trailingLabel!,
                  style: TermexTypography.body.copyWith(
                    color: TermexColors.danger,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.hint});
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TermexTypography.body.copyWith(
                color: TermexColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TermexSpacing.sm),
            Text(
              hint,
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.event,
    this.onLongPress,
    this.highlightTokens = const [],
  });
  final TaskEvent event;
  final VoidCallback? onLongPress;

  /// v0.79.42 + v0.79.46: substrings of these (lowercased, non-empty)
  /// tokens in title/summary get a yellow inline background. Empty list
  /// = plain Text (no RichText overhead).
  final List<String> highlightTokens;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Clickable(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      onTap: () => Navigator.of(context).push(PageRouteBuilder<void>(
        pageBuilder: (ctx, _, __) =>
            MobileTaskDetailPage(taskId: event.taskId),
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: TermexColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusDot(status: event.status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightedText(
                    text: event.title,
                    needles: highlightTokens,
                    maxLines: 1,
                    baseStyle: TermexTypography.body.copyWith(
                      color: TermexColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _HighlightedText(
                    text: event.summary,
                    needles: highlightTokens,
                    maxLines: 2,
                    baseStyle: TermexTypography.caption.copyWith(
                      color: TermexColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _relative(event.occurredAt, l10n),
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _relative(DateTime when, AppLocalizations l10n) {
    final delta = DateTime.now().difference(when);
    if (delta.inSeconds < 60) {
      return l10n.taskHistoryRelativeSecondsAgo(delta.inSeconds.clamp(1, 59));
    }
    if (delta.inMinutes < 60) {
      return l10n.taskHistoryRelativeMinutesAgo(delta.inMinutes);
    }
    if (delta.inHours < 24) {
      return l10n.taskHistoryRelativeHoursAgo(delta.inHours);
    }
    return l10n.taskHistoryRelativeDaysAgo(delta.inDays);
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final TaskEventStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TaskEventStatus.succeeded => TermexColors.success,
      TaskEventStatus.failed => TermexColors.danger,
      TaskEventStatus.cancelled => TermexColors.warning,
      TaskEventStatus.running => TermexColors.primary,
      TaskEventStatus.pending => TermexColors.textMuted,
      TaskEventStatus.pendingConfirmation => TermexColors.warning,
    };
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// v0.79.35: horizontal scroll-row of filter chips above the list.
/// Selected = solid primary color; unselected = subtle outline.
class _SourceFilterChips extends StatelessWidget {
  const _SourceFilterChips({
    required this.selected,
    required this.counts,
    required this.allLabel,
    required this.sftpLabel,
    required this.aiLabel,
    required this.otherLabel,
    required this.onSelect,
  });

  final TaskSource? selected;
  final ({int total, int sftp, int ai, int other}) counts;
  final String allLabel;
  final String sftpLabel;
  final String aiLabel;
  final String otherLabel;

  /// Pass null for the "all" chip.
  final void Function(TaskSource? source) onSelect;

  @override
  Widget build(BuildContext context) {
    // Hide chips for sources with zero entries — keeps the row visually
    // clean for fresh installs / single-source use.
    final chips = <Widget>[
      _Chip(
        label: '$allLabel · ${counts.total}',
        active: selected == null,
        onTap: () => onSelect(null),
      ),
    ];
    if (counts.sftp > 0) {
      chips.add(_Chip(
        label: '$sftpLabel · ${counts.sftp}',
        active: selected == TaskSource.sftp,
        onTap: () => onSelect(TaskSource.sftp),
      ));
    }
    if (counts.ai > 0) {
      chips.add(_Chip(
        label: '$aiLabel · ${counts.ai}',
        active: selected == TaskSource.ai,
        onTap: () => onSelect(TaskSource.ai),
      ));
    }
    if (counts.other > 0) {
      chips.add(_Chip(
        label: '$otherLabel · ${counts.other}',
        active: selected == TaskSource.other,
        onTap: () => onSelect(TaskSource.other),
      ));
    }
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Clickable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? TermexColors.primary
              : TermexColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? TermexColors.primary : TermexColors.border,
          ),
        ),
        child: Text(
          label,
          style: TermexTypography.bodySmall.copyWith(
            color: active
                ? const Color(0xFFFFFFFF)
                : TermexColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// v0.79.40: text search input above the filter chips. Auto-trimming +
/// lowercase + reactive — every keystroke triggers a single setState in
/// the parent, no debounce since the per-row filter cost is trivial
/// (taskId + title + summary string comparisons over ≤ low-hundreds of
/// rows). When [hasQuery] is true a clear `×` is shown at the trailing
/// edge.
class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasQuery,
    required this.placeholder,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasQuery;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TermexTextField(
        controller: controller,
        placeholder: placeholder,
        onChanged: onChanged,
        leadingIcon: const Icon(
          TermexIcons.search,
          size: 16,
          color: TermexColors.textSecondary,
        ),
        trailing: hasQuery
            ? Clickable(
                behavior: HitTestBehavior.opaque,
                onTap: onClear,
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(
                    TermexIcons.close,
                    size: 16,
                    color: TermexColors.textSecondary,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// v0.79.39: red panel revealed under a row as the user swipes left to
/// dismiss it. Visual matches iOS/Android conventions — destructive red
/// + trash icon at the trailing edge. Confirmation still gates the
/// actual delete via [Dismissible.confirmDismiss].
class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TermexColors.danger,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(
        TermexIcons.delete,
        size: 22,
        color: Color(0xFFFFFFFF),
      ),
    );
  }
}

/// v0.79.42 + v0.79.46: renders a string with yellow inline background
/// on substrings matching any of the (lowercased, trimmed, non-empty)
/// needles. Falls back to plain `Text` when needles list is empty —
/// keeps the row's render cost identical to the pre-v0.79.42 path when
/// search isn't active (the common case).
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.needles,
    required this.baseStyle,
    required this.maxLines,
  });

  final String text;
  final List<String> needles;
  final TextStyle baseStyle;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (needles.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }
    final segments = splitHighlightAll(text, needles);
    // No-match short-circuit: single non-match segment carries the full
    // string → render plain Text to avoid a TextSpan tree allocation.
    if (segments.length == 1 && !segments.first.isMatch) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }
    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: [
          for (final seg in segments)
            TextSpan(
              text: seg.text,
              style: seg.isMatch
                  ? const TextStyle(
                      backgroundColor: Color(0xFFFFD93D),
                      color: Color(0xFF1F1B0F), // dark on yellow for AA
                      fontWeight: FontWeight.w600,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
