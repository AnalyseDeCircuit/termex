import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/task/model/task_view_model.dart';
import 'package:termex_shared/features/task/widgets/task_queue_panel.dart';

TaskViewModel _t(String id, TaskStatus status) => TaskViewModel(
      id: id,
      serverId: 's',
      serverName: 'home-dev',
      prompt: 'task-$id',
      status: status,
      aiCliKind: AiCliKind.generic,
      startedAt: DateTime.utc(2026, 5, 23, 10, 0, 0),
    );

Widget host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(375, 700)),
      child: SizedBox(width: 375, height: 600, child: child),
    ),
  );
}

void main() {
  testWidgets('tab counts reflect bucketed tasks', (tester) async {
    final tasks = [
      _t('r1', TaskStatus.running),
      _t('r2', TaskStatus.running),
      _t('p1', TaskStatus.pending),
      _t('c1', TaskStatus.succeeded),
      _t('c2', TaskStatus.failed),
    ];
    await tester.pumpWidget(host(TaskQueuePanel(
      tasks: tasks,
      onOpenDetail: (_) {},
    )));
    expect(find.text('Running (2)'), findsOneWidget);
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('Completed (2)'), findsOneWidget);
  });

  testWidgets('switching tab swaps the list', (tester) async {
    final tasks = [
      _t('r1', TaskStatus.running),
      _t('p1', TaskStatus.pending),
    ];
    await tester.pumpWidget(host(TaskQueuePanel(
      tasks: tasks,
      onOpenDetail: (_) {},
    )));
    expect(find.text('task-r1'), findsOneWidget);
    expect(find.text('task-p1'), findsNothing);

    await tester.tap(find.text('Pending (1)'));
    await tester.pump();
    expect(find.text('task-p1'), findsOneWidget);
    expect(find.text('task-r1'), findsNothing);
  });

  testWidgets('empty tab shows guidance string', (tester) async {
    await tester.pumpWidget(host(TaskQueuePanel(
      tasks: const [],
      onOpenDetail: (_) {},
    )));
    expect(find.textContaining('No tasks running'), findsOneWidget);
  });

  testWidgets('open detail tap invokes callback', (tester) async {
    String? opened;
    await tester.pumpWidget(host(TaskQueuePanel(
      tasks: [_t('r1', TaskStatus.running)],
      onOpenDetail: (t) => opened = t.id,
    )));
    await tester.tap(find.text('Details ›'));
    await tester.pump();
    expect(opened, 'r1');
  });

  testWidgets('cancel callback wired through TaskCard', (tester) async {
    String? cancelled;
    await tester.pumpWidget(host(TaskQueuePanel(
      tasks: [_t('r1', TaskStatus.running)],
      onOpenDetail: (_) {},
      onCancel: (t) => cancelled = t.id,
    )));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(cancelled, 'r1');
  });

  testWidgets('pending_confirmation tasks bucket under Pending',
      (tester) async {
    final tasks = [
      _t('pc1', TaskStatus.pendingConfirmation),
    ];
    await tester.pumpWidget(host(TaskQueuePanel(
      tasks: tasks,
      onOpenDetail: (_) {},
    )));
    expect(find.text('Pending (1)'), findsOneWidget);
    await tester.tap(find.text('Pending (1)'));
    await tester.pump();
    expect(find.text('task-pc1'), findsOneWidget);
  });
}
