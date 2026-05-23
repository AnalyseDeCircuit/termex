/// Top-level dashboard composing the task queue panel + a FAB-style
/// "Assign task" entry point.
library;

import 'package:flutter/widgets.dart';

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import 'model/task_view_model.dart';
import 'widgets/assign_task_sheet.dart';
import 'widgets/task_queue_panel.dart';

class TaskDashboardScreen extends StatelessWidget {
  final List<TaskViewModel> tasks;
  final List<ServerOption> servers;
  final void Function(TaskViewModel) onOpenDetail;
  final AssignSubmit onAssign;
  final void Function(TaskViewModel)? onCancel;

  const TaskDashboardScreen({
    super.key,
    required this.tasks,
    required this.servers,
    required this.onOpenDetail,
    required this.onAssign,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _AppBar(),
            Expanded(
              child: TaskQueuePanel(
                tasks: tasks,
                onOpenDetail: onOpenDetail,
                onCancel: onCancel,
              ),
            ),
          ],
        ),
        Positioned(
          right: TermexSpacing.md,
          bottom: TermexSpacing.lg,
          child: _AssignFab(servers: servers, onSubmit: onAssign),
        ),
      ],
    );
  }
}

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.md),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: TermexColors.border),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Tasks',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignFab extends StatelessWidget {
  final List<ServerOption> servers;
  final AssignSubmit onSubmit;

  const _AssignFab({required this.servers, required this.onSubmit});

  void _show(BuildContext context) {
    Navigator.of(context).push<void>(_BottomSheetRoute(
      child: AssignTaskSheet(servers: servers, onSubmit: onSubmit),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _show(context),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: TermexColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: TermexColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '+',
            style: TermexTypography.heading1.copyWith(
              color: TermexColors.textPrimary,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal bottom-sheet route so we don't pull in Material here.
class _BottomSheetRoute extends PopupRoute<void> {
  final Widget child;
  _BottomSheetRoute({required this.child});

  @override
  Color? get barrierColor => const Color(0x80000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: animation.drive(
          Tween(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: SafeArea(top: false, child: child),
      ),
    );
  }
}
