import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens.dart';
import '../state/settings_provider.dart';

class AuditTab extends ConsumerStatefulWidget {
  const AuditTab({super.key});
  @override
  ConsumerState<AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends ConsumerState<AuditTab> {
  String? _filterType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(settingsProvider.notifier).loadAuditLogs());
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(settingsProvider).auditLogs;

    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: TermexColors.border)),
          ),
          child: Row(
            children: [
              Text('事件类型：',
                  style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _filterType,
                dropdownColor: TermexColors.backgroundSecondary,
                style: TextStyle(fontSize: 12, color: TermexColors.textPrimary),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部')),
                  ...['ssh_connect', 'server_create', 'ai_chat', 'sftp_transfer']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t))),
                ],
                onChanged: (v) {
                  setState(() => _filterType = v);
                  ref.read(settingsProvider.notifier).loadAuditLogs(eventType: v);
                },
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_rounded, size: 13),
                label: const Text('导出 CSV', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: TermexColors.textSecondary),
              ),
            ],
          ),
        ),
        // Table header
        _TableRow(isHeader: true, cells: const ['时间', '事件', '详情']),
        const Divider(height: 1),
        Expanded(
          child: logs.isEmpty
              ? Center(
                  child: Text('暂无审计日志',
                      style: TextStyle(
                          fontSize: 12, color: TermexColors.textSecondary)),
                )
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (_, i) {
                    final log = logs[i];
                    return _TableRow(cells: [
                      _formatDate(log.createdAt),
                      log.eventType,
                      log.detail,
                    ]);
                  },
                ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${_p(dt.month)}-${_p(dt.day)} ${_p(dt.hour)}:${_p(dt.minute)}:${_p(dt.second)}';
  String _p(int n) => n.toString().padLeft(2, '0');
}

class _TableRow extends StatelessWidget {
  final List<String> cells;
  final bool isHeader;
  const _TableRow({required this.cells, this.isHeader = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: isHeader ? TermexColors.backgroundTertiary : null,
        border: Border(
            bottom: BorderSide(color: TermexColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 160,
              child: _CellText(cells[0], isHeader: isHeader)),
          SizedBox(
              width: 120,
              child: _CellText(cells[1], isHeader: isHeader)),
          Expanded(child: _CellText(cells[2], isHeader: isHeader)),
        ],
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  final String text;
  final bool isHeader;
  const _CellText(this.text, {this.isHeader = false});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 10 : 12,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.normal,
          color: isHeader ? TermexColors.textSecondary : TermexColors.textPrimary,
          letterSpacing: isHeader ? 0.5 : 0,
        ),
      );
}
