/// Process list table for the Monitor panel.
///
/// Renders `ProcessInfo[]` as a sortable list: PID / User / CPU% / Mem% /
/// Command. The sort toggle lives in the section header and emits via
/// `onSortChanged`. The legacy Tauri UX allows sending signals — that's
/// deferred until the OSS bridge wires `monitor_send_signal` against a
/// real SSH session (currently a stub).
library;

import 'package:flutter/widgets.dart';
import 'package:termex_bridge/api.dart' as bridge;

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../widgets/clickable.dart';

enum ProcessSort { cpu, mem }

class ProcessListView extends StatelessWidget {
  final List<bridge.ProcessInfo> processes;
  final ProcessSort sort;
  final ValueChanged<ProcessSort> onSortChanged;

  const ProcessListView({
    super.key,
    required this.processes,
    required this.sort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...processes]..sort((a, b) {
        final ax = sort == ProcessSort.cpu ? a.cpuPercent : a.memoryPercent;
        final bx = sort == ProcessSort.cpu ? b.cpuPercent : b.memoryPercent;
        return bx.compareTo(ax);
      });
    return Container(
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border.all(color: context.colors.border, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(sort: sort, onSortChanged: onSortChanged),
          const Divider(),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.all(TermexSpacing.md),
              child: Text(
                '暂无进程数据',
                style: TermexTypography.caption,
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sorted.length,
              itemBuilder: (_, i) => _Row(p: sorted[i]),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ProcessSort sort;
  final ValueChanged<ProcessSort> onSortChanged;

  const _Header({required this.sort, required this.onSortChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.md,
          vertical: TermexSpacing.sm,
        ),
        child: Row(
          children: [
            Text(
              '进程',
              style: TermexTypography.caption.copyWith(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            _SortChip(
              label: 'CPU',
              active: sort == ProcessSort.cpu,
              onTap: () => onSortChanged(ProcessSort.cpu),
            ),
            const SizedBox(width: 4),
            _SortChip(
              label: 'MEM',
              active: sort == ProcessSort.mem,
              onTap: () => onSortChanged(ProcessSort.mem),
            ),
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  final bridge.ProcessInfo p;
  const _Row({required this.p});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TermexSpacing.md,
          vertical: 4,
        ),
        child: Row(
          children: [
            _col(context, '${p.pid}', 50),
            _col(context, p.user, 70),
            _col(context, '${p.cpuPercent.toStringAsFixed(1)}%', 50,
                mono: true),
            _col(context, '${p.memoryPercent.toStringAsFixed(1)}%', 50,
                mono: true),
            Expanded(
              child: Text(
                p.command,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TermexTypography.caption.copyWith(
                  color: context.colors.textPrimary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      );

  Widget _col(BuildContext context, String s, double w,
          {bool mono = false}) =>
      SizedBox(
        width: w,
        child: Text(
          s,
          style: TermexTypography.caption.copyWith(
            color: context.colors.textSecondary,
            fontFamily: mono ? 'monospace' : null,
          ),
        ),
      );
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Clickable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: active
                ? context.colors.primary.withValues(alpha: 0.12)
                : const Color(0x00000000),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: active ? context.colors.primary : context.colors.border,
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TermexTypography.caption.copyWith(
              fontSize: 10,
              color: active ? context.colors.primary : context.colors.textMuted,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      );
}

class Divider extends StatelessWidget {
  const Divider({super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 0.5,
        color: context.colors.border,
      );
}
