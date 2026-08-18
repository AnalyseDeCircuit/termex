/// Audit log dashboard — the main view rendered inside the settings
/// Audit tab.
///
/// Composes:
///   - 5 KPI summary cards (total / connections / credential access /
///     config changes / member ops)
///   - [AuditFilterBar] (date range chips + event-type chips + export)
///   - Paginated table where each row opens [showAuditDetailDialog]
///
/// Replaces the previous bare ListView in [AuditTab] which v0.62.1 listed
/// as "AuditDashboard 完全缺失" — this widget closes that gap.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/colors.dart';
import '../../../../design/spacing.dart';
import '../../../../design/typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../widgets/clickable.dart';
import '../../state/settings_provider.dart';
import 'audit_detail_dialog.dart';
import 'audit_filter_bar.dart';

const int _kPageSize = 20;

class AuditDashboard extends ConsumerStatefulWidget {
  const AuditDashboard({super.key});

  @override
  ConsumerState<AuditDashboard> createState() => _AuditDashboardState();
}

class _AuditDashboardState extends ConsumerState<AuditDashboard> {
  AuditFilter _filter = const AuditFilter();
  int _page = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).loadAuditLogs();
    });
  }

  List<AuditLogEntry> _applyFilter(List<AuditLogEntry> all) {
    return all
        .where((e) => _filter.matchesEntry(e.createdAt, e.eventType))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final raw = ref.watch(settingsProvider).auditLogs;
    final filtered = _applyFilter(raw);
    final summary = _Summary.fromEntries(filtered);

    final totalPages = ((filtered.length + _kPageSize - 1) ~/ _kPageSize)
        .clamp(1, 9999);
    final pg = _page.clamp(1, totalPages);
    final start = (pg - 1) * _kPageSize;
    final end = (start + _kPageSize).clamp(0, filtered.length);
    final pageItems = filtered.sublist(start, end);

    // The whole dashboard scrolls vertically — the audit filter bar's
    // event-type Wrap (~50 known events) plus a 20-row table easily
    // exceeds the embedded settings dialog body (500 px). Previous
    // Column + Expanded layout collapsed the table or overflowed.
    return ListView(
      padding: const EdgeInsets.all(TermexSpacing.md),
      children: [
        _SummaryRow(summary: summary),
        const SizedBox(height: TermexSpacing.md),
        AuditFilterBar(
          filter: _filter,
          onFilterChanged: (f) => setState(() {
            _filter = f;
            _page = 1;
          }),
          allEntriesJson: filtered
              .map((e) => {
                    'id': e.id,
                    'eventType': e.eventType,
                    'detail': e.detail,
                    'createdAt': e.createdAt.toIso8601String(),
                  })
              .toList(),
        ),
        const SizedBox(height: TermexSpacing.md),
        if (filtered.isEmpty)
          const SizedBox(height: 200, child: _EmptyState())
        else
          _LogTable(
            items: pageItems,
            onRowTap: (e) => showAuditDetailDialog(context, e),
          ),
        if (filtered.length > _kPageSize) ...[
          const SizedBox(height: TermexSpacing.sm),
          _Pager(
            page: pg,
            totalPages: totalPages,
            onPrev: pg > 1 ? () => setState(() => _page = pg - 1) : null,
            onNext: pg < totalPages
                ? () => setState(() => _page = pg + 1)
                : null,
          ),
        ],
      ],
    );
  }
}

// ─── Summary KPIs ────────────────────────────────────────────────────────

class _Summary {
  final int total;
  final int connections;
  final int credentialAccess;
  final int configChanges;
  final int memberOps;

  const _Summary({
    required this.total,
    required this.connections,
    required this.credentialAccess,
    required this.configChanges,
    required this.memberOps,
  });

  factory _Summary.fromEntries(List<AuditLogEntry> es) {
    var conn = 0, cred = 0, conf = 0, member = 0;
    for (final e in es) {
      final t = e.eventType;
      if (t.startsWith('ssh_') || t.startsWith('connection_')) conn++;
      if (t.contains('credential') || t.contains('keychain')) cred++;
      if (t.contains('settings') || t.contains('config_')) conf++;
      if (t.startsWith('team_') || t.contains('member')) member++;
    }
    return _Summary(
      total: es.length,
      connections: conn,
      credentialAccess: cred,
      configChanges: conf,
      memberOps: member,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final _Summary summary;
  const _SummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <_Kpi>[
      _Kpi(l10n.auditKpiTotal, summary.total, context.colors.primary),
      _Kpi(l10n.auditKpiConnections, summary.connections, context.colors.success),
      _Kpi(l10n.auditKpiCredentialAccess, summary.credentialAccess,
          context.colors.warning),
      _Kpi(l10n.auditKpiConfigChanges, summary.configChanges,
          const Color(0xFF8B5CF6)),
      _Kpi(l10n.auditKpiMemberOps, summary.memberOps, context.colors.danger),
    ];
    return LayoutBuilder(
      builder: (ctx, c) {
        final narrow = c.maxWidth < 600;
        if (narrow) {
          // 2-column grid on narrow panes
          final rows = <Widget>[];
          for (var i = 0; i < items.length; i += 2) {
            final left = _KpiCard(kpi: items[i]);
            final right = i + 1 < items.length
                ? _KpiCard(kpi: items[i + 1])
                : const Expanded(child: SizedBox());
            rows.add(Row(
              children: [
                Expanded(child: left),
                const SizedBox(width: TermexSpacing.sm),
                if (right is Expanded) right else Expanded(child: right),
              ],
            ));
            if (i + 2 < items.length) {
              rows.add(const SizedBox(height: TermexSpacing.sm));
            }
          }
          return Column(children: rows);
        }
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: _KpiCard(kpi: items[i])),
              if (i < items.length - 1)
                const SizedBox(width: TermexSpacing.sm),
            ]
          ],
        );
      },
    );
  }
}

class _Kpi {
  final String label;
  final int value;
  final Color color;
  const _Kpi(this.label, this.value, this.color);
}

class _KpiCard extends StatelessWidget {
  final _Kpi kpi;
  const _KpiCard({required this.kpi});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(TermexSpacing.md),
        decoration: BoxDecoration(
          color: context.colors.backgroundSecondary,
          border: Border.all(color: context.colors.border, width: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: kpi.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: TermexSpacing.sm),
                Expanded(
                  child: Text(
                    kpi.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TermexTypography.caption.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${kpi.value}',
              style: TermexTypography.body.copyWith(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ],
        ),
      );
}

// ─── Log table ────────────────────────────────────────────────────────────

class _LogTable extends StatelessWidget {
  final List<AuditLogEntry> items;
  final void Function(AuditLogEntry) onRowTap;

  const _LogTable({required this.items, required this.onRowTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border.all(color: context.colors.border, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TermexSpacing.md,
              vertical: TermexSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.colors.border, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(l10n.auditFieldTime,
                      style: TermexTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                SizedBox(
                  width: 160,
                  child: Text(l10n.auditColEvent,
                      style: TermexTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: Text(l10n.auditFieldDetail,
                      style: TermexTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          // shrinkWrap + NeverScrollable so we behave well inside the
          // outer dashboard ListView (avoiding nested-scroll conflict).
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (_, i) => _LogRow(
              entry: items[i],
              onTap: () => onRowTap(items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatefulWidget {
  final AuditLogEntry entry;
  final VoidCallback onTap;

  const _LogRow({required this.entry, required this.onTap});

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Clickable(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TermexSpacing.md,
              vertical: TermexSpacing.sm,
            ),
            color: _hovered
                ? context.colors.backgroundTertiary
                : const Color(0x00000000),
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    _fmt(widget.entry.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TermexTypography.caption.copyWith(
                      color: context.colors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: Text(
                    widget.entry.eventType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TermexTypography.caption.copyWith(
                      color: context.colors.textPrimary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.entry.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TermexTypography.caption.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  String _fmt(DateTime dt) {
    String two(int v) => v < 10 ? '0$v' : '$v';
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}

// ─── Pager ────────────────────────────────────────────────────────────────

class _Pager extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _Pager({
    required this.page,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PageBtn(label: l10n.auditPagerPrev, onTap: onPrev),
        const SizedBox(width: TermexSpacing.md),
        Text(
          '$page / $totalPages',
          style: TermexTypography.caption.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(width: TermexSpacing.md),
        _PageBtn(label: l10n.auditPagerNext, onTap: onNext),
      ],
    );
  }
}

class _PageBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _PageBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Clickable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.md,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: enabled
              ? context.colors.backgroundSecondary
              : const Color(0x00000000),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: enabled ? context.colors.border : context.colors.backgroundTertiary,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TermexTypography.caption.copyWith(
            color: enabled ? context.colors.textPrimary : context.colors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ─── Empty ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.auditEmptyTitle,
            style: TermexTypography.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: TermexSpacing.sm),
          Text(
            l10n.auditEmptyHint,
            style: TermexTypography.caption.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
