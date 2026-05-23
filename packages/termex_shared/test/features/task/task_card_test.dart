import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/task/model/task_view_model.dart';
import 'package:termex_shared/features/task/widgets/task_card.dart';

TaskViewModel make({
  TaskStatus status = TaskStatus.running,
  String prompt = 'fix bug',
  String? outputTail,
  List<ArtifactSummary> artifacts = const [],
  int? input,
  int? output,
  double? cost,
}) {
  return TaskViewModel(
    id: 't1',
    serverId: 's1',
    serverName: 'home-dev',
    prompt: prompt,
    status: status,
    aiCliKind: AiCliKind.claudeCode,
    startedAt: DateTime.utc(2026, 5, 23, 10, 0, 0),
    endedAt: DateTime.utc(2026, 5, 23, 10, 0, 10),
    outputTail: outputTail,
    artifactSummaries: artifacts,
    totalInputTokens: input ?? 0,
    totalOutputTokens: output ?? 0,
    estimatedCostUsd: cost,
  );
}

Widget host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(375, 700)),
      child: child,
    ),
  );
}

void main() {
  testWidgets('renders prompt + server + elapsed + status', (tester) async {
    final task = make(status: TaskStatus.running);
    await tester.pumpWidget(host(TaskCard(task: task)));
    expect(find.text('fix bug'), findsOneWidget);
    expect(find.textContaining('home-dev'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
  });

  testWidgets('cancel button visible only when non-terminal', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(host(TaskCard(
      task: make(status: TaskStatus.running),
      onCancel: () => cancelled = true,
    )));
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(cancelled, isTrue);

    await tester.pumpWidget(host(TaskCard(
      task: make(status: TaskStatus.succeeded),
      onCancel: () {},
    )));
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('shows artifact count + token cost when available',
      (tester) async {
    final task = make(
      artifacts: [
        ArtifactSummary(
          id: 'a',
          kind: 'diff',
          sizeBytes: 100,
          createdAt: DateTime.utc(2026, 5, 23),
        ),
      ],
      input: 5400,
      output: 3000,
      cost: 0.12,
    );
    await tester.pumpWidget(host(TaskCard(task: task)));
    expect(find.textContaining('1 artifacts'), findsOneWidget);
    expect(find.textContaining('8.4K tokens'), findsOneWidget);
    expect(find.textContaining('\$0.12'), findsOneWidget);
  });

  testWidgets('output tail truncated to first line', (tester) async {
    final task = make(outputTail: 'line1\nline2\nline3');
    await tester.pumpWidget(host(TaskCard(task: task)));
    expect(find.text('line1'), findsOneWidget);
    expect(find.text('line2'), findsNothing);
  });

  testWidgets('details button triggers onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(TaskCard(
      task: make(status: TaskStatus.succeeded),
      onTap: () => tapped = true,
    )));
    expect(find.text('Details ›'), findsOneWidget);
    await tester.tap(find.text('Details ›'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
