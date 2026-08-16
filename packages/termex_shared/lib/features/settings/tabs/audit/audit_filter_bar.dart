/// Filter bar for the audit log tab.
///
/// Provides:
///   - Date range quick-select chips (今天 / 本周 / 本月 / 全部)
///   - Event type multi-select chips (loaded from [auditListKnownEvents])
///   - Export dropdown (CSV / JSON)
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../../../../design/colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Preset date-range option.
enum AuditDateRange { today, week, month, all }

/// Current filter state passed down from the parent tab.
class AuditFilter {
  final AuditDateRange dateRange;
  final Set<String> eventTypes; // empty = all types

  const AuditFilter({
    this.dateRange = AuditDateRange.all,
    this.eventTypes = const {},
  });

  AuditFilter copyWith({
    AuditDateRange? dateRange,
    Set<String>? eventTypes,
  }) =>
      AuditFilter(
        dateRange: dateRange ?? this.dateRange,
        eventTypes: eventTypes ?? this.eventTypes,
      );

  bool matchesEntry(DateTime createdAt, String eventType) {
    if (!_matchesDate(createdAt)) return false;
    if (eventTypes.isNotEmpty && !eventTypes.contains(eventType)) return false;
    return true;
  }

  bool _matchesDate(DateTime dt) {
    final now = DateTime.now();
    return switch (dateRange) {
      AuditDateRange.today => dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day,
      AuditDateRange.week => now.difference(dt).inDays <= 7,
      AuditDateRange.month => now.difference(dt).inDays <= 30,
      AuditDateRange.all => true,
    };
  }
}

class AuditFilterBar extends ConsumerStatefulWidget {
  final AuditFilter filter;
  final ValueChanged<AuditFilter> onFilterChanged;

  /// All audit entries — needed for JSON export.
  final List<Map<String, dynamic>> allEntriesJson;

  const AuditFilterBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    this.allEntriesJson = const [],
  });

  @override
  ConsumerState<AuditFilterBar> createState() => _AuditFilterBarState();
}

class _AuditFilterBarState extends ConsumerState<AuditFilterBar> {
  List<String> _knownEvents = [];
  String? _exportMessage;

  @override
  void initState() {
    super.initState();
    _loadKnownEvents();
  }

  Future<void> _loadKnownEvents() async {
    try {
      final events = await bridge.auditListKnownEvents();
      if (mounted) setState(() => _knownEvents = events);
    } catch (_) {}
  }

  Future<void> _exportCsv() async {
    final l10n = AppLocalizations.of(context);
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final path = 'termex-audit-$ts.csv';
    try {
      await bridge.auditExportCsv(path: path);
      if (mounted) setState(() => _exportMessage = l10n.auditExported(path));
    } catch (e) {
      if (mounted) setState(() => _exportMessage = l10n.auditExportFailed('$e'));
    }
  }

  Future<void> _exportJson() async {
    final l10n = AppLocalizations.of(context);
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final path = 'termex-audit-$ts.json';
    try {
      final encoded = const JsonEncoder.withIndent('  ')
          .convert(widget.allEntriesJson);
      await File(path).writeAsString(encoded);
      if (mounted) setState(() => _exportMessage = l10n.auditExported(path));
    } catch (e) {
      if (mounted) setState(() => _exportMessage = l10n.auditExportFailed('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: date range chips + export
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _label(l10n.auditLabelDate),
                _dateChip(l10n.auditRangeToday, AuditDateRange.today),
                const SizedBox(width: 4),
                _dateChip(l10n.auditRangeWeek, AuditDateRange.week),
                const SizedBox(width: 4),
                _dateChip(l10n.auditRangeMonth, AuditDateRange.month),
                const SizedBox(width: 4),
                _dateChip(l10n.auditRangeAll, AuditDateRange.all),
                const Spacer(),
                if (_exportMessage != null) ...[
                  Text(_exportMessage!,
                      style: const TextStyle(
                          fontSize: 10, color: TermexColors.textMuted)),
                  const SizedBox(width: 8),
                ],
                PopupMenuButton<String>(
                  tooltip: l10n.auditExport,
                  color: TermexColors.backgroundSecondary,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: TermexColors.border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download_outlined,
                            size: 13, color: TermexColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(l10n.auditExport,
                            style: const TextStyle(
                                fontSize: 11,
                                color: TermexColors.textSecondary)),
                      ],
                    ),
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'csv',
                      child: Text(l10n.auditExportCsv,
                          style: const TextStyle(
                              fontSize: 12, color: TermexColors.textPrimary)),
                    ),
                    PopupMenuItem(
                      value: 'json',
                      child: Text(l10n.auditExportJson,
                          style: const TextStyle(
                              fontSize: 12, color: TermexColors.textPrimary)),
                    ),
                  ],
                  onSelected: (v) => v == 'csv' ? _exportCsv() : _exportJson(),
                ),
              ],
            ),
          ),
          // Row 2: event type chips (only if known events loaded)
          if (_knownEvents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
              child: Row(
                children: [
                  _label(l10n.auditLabelEvent),
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        for (final e in _knownEvents) _eventChip(e),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, color: TermexColors.textSecondary)),
      );

  Widget _dateChip(String label, AuditDateRange range) {
    final selected = widget.filter.dateRange == range;
    return _Chip(
      label: label,
      isSelected: selected,
      onTap: () => widget.onFilterChanged(
          widget.filter.copyWith(dateRange: range)),
    );
  }

  Widget _eventChip(String eventType) {
    final selected = widget.filter.eventTypes.contains(eventType);
    return _Chip(
      label: eventType,
      isSelected: selected,
      onTap: () {
        final types = Set<String>.from(widget.filter.eventTypes);
        if (!types.remove(eventType)) types.add(eventType);
        widget.onFilterChanged(widget.filter.copyWith(eventTypes: types));
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? TermexColors.primary.withOpacity(0.15)
              : TermexColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? TermexColors.primary : TermexColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? TermexColors.primary : TermexColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
