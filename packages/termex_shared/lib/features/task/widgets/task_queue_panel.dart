/// Three-tab task queue (Running / Pending / Completed).
///
/// Renders a [TaskCard] per row. Tab counts update reactively from
/// the parent's task list. Empty state per tab is a one-liner so the
/// dashboard never looks broken.
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../widgets/clickable.dart';
import '../model/task_view_model.dart';
import 'task_card.dart';

class TaskQueuePanel extends StatefulWidget {
  final List<TaskViewModel> tasks;
  final void Function(TaskViewModel) onOpenDetail;
  final void Function(TaskViewModel)? onCancel;

  const TaskQueuePanel({
    super.key,
    required this.tasks,
    required this.onOpenDetail,
    this.onCancel,
  });

  @override
  State<TaskQueuePanel> createState() => _TaskQueuePanelState();
}

class _TaskQueuePanelState extends State<TaskQueuePanel> {
  _TabKind _active = _TabKind.running;

  @override
  Widget build(BuildContext context) {
    final running = widget.tasks
        .where((t) => t.status == TaskStatus.running)
        .toList();
    final pending = widget.tasks
        .where((t) =>
            t.status == TaskStatus.pending ||
            t.status == TaskStatus.pendingConfirmation)
        .toList();
    final completed = widget.tasks
        .where((t) => t.status.isTerminal)
        .toList();

    final visible = switch (_active) {
      _TabKind.running => running,
      _TabKind.pending => pending,
      _TabKind.completed => completed,
    };

    return Column(
      children: [
        _Tabs(
          active: _active,
          runningCount: running.length,
          pendingCount: pending.length,
          completedCount: completed.length,
          onSelect: (k) => setState(() => _active = k),
        ),
        Expanded(
          child: visible.isEmpty
              ? _EmptyState(kind: _active)
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, i) => TaskCard(
                    task: visible[i],
                    onTap: () => widget.onOpenDetail(visible[i]),
                    onCancel: widget.onCancel == null
                        ? null
                        : () => widget.onCancel!(visible[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

enum _TabKind { running, pending, completed }

class _Tabs extends StatelessWidget {
  final _TabKind active;
  final int runningCount;
  final int pendingCount;
  final int completedCount;
  final ValueChanged<_TabKind> onSelect;

  const _Tabs({
    required this.active,
    required this.runningCount,
    required this.pendingCount,
    required this.completedCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colors.border),
        ),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Running',
            count: runningCount,
            active: active == _TabKind.running,
            onTap: () => onSelect(_TabKind.running),
          ),
          _Tab(
            label: 'Pending',
            count: pendingCount,
            active: active == _TabKind.pending,
            onTap: () => onSelect(_TabKind.pending),
          ),
          _Tab(
            label: 'Completed',
            count: completedCount,
            active: active == _TabKind.completed,
            onTap: () => onSelect(_TabKind.completed),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _Tab({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Clickable(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? context.colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$label ($count)',
            style: TermexTypography.body.copyWith(
              color: active
                  ? context.colors.textPrimary
                  : context.colors.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final _TabKind kind;
  const _EmptyState({required this.kind});

  @override
  Widget build(BuildContext context) {
    final msg = switch (kind) {
      _TabKind.running => 'No tasks running. Tap + to assign one.',
      _TabKind.pending => 'No pending tasks.',
      _TabKind.completed => 'No completed tasks yet.',
    };
    return Padding(
      padding: const EdgeInsets.all(TermexSpacing.xl),
      child: Center(
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: TermexTypography.body.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Internal `Colors.transparent` shim — termex_shared doesn't import
/// material; we only need a fully-transparent sentinel.
class Colors {
  static const Color transparent = Color(0x00000000);
}
