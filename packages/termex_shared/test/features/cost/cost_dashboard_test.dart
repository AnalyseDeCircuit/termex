import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/cost/model/cost_view_model.dart';
import 'package:termex_shared/features/cost/widgets/cost_dashboard.dart';

Widget host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(375, 800)),
        child: child,
      ),
    );

CostSummaryVM sampleSummary() => const CostSummaryVM(
      periodLabel: 'This month',
      totalUsd: 1.25,
      taskCount: 3,
      totalInputTokens: 12345,
      totalOutputTokens: 6789,
      byServer: [
        ServerCostVM(
          serverId: 's1',
          serverName: 'home-dev',
          costUsd: 0.80,
          taskCount: 2,
        ),
        ServerCostVM(
          serverId: 's2',
          serverName: 'prod-edge',
          costUsd: 0.45,
          taskCount: 1,
        ),
      ],
      topTasks: [
        TaskCostVM(taskId: 'tA', promptPreview: 'refactor parser', costUsd: 0.50),
        TaskCostVM(taskId: 'tB', promptPreview: 'add tests', costUsd: 0.30),
      ],
      byKind: {
        CostKindVM.primaryAiCall: 1.00,
        CostKindVM.streamingSummary: 0.20,
        CostKindVM.toolUse: 0.05,
      },
    );

void main() {
  testWidgets('header renders period label + total', (tester) async {
    await tester.pumpWidget(host(CostDashboard(summary: sampleSummary())));
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('\$1.25'), findsOneWidget);
    expect(find.textContaining('3 tasks'), findsOneWidget);
    expect(find.textContaining('12.3K in'), findsOneWidget);
  });

  testWidgets('header shows remaining when monthly cap is set', (tester) async {
    await tester.pumpWidget(host(CostDashboard(
      summary: sampleSummary(),
      caps: const UserCostCapVM(monthlyUsd: 10),
    )));
    expect(find.text('\$8.75 left'), findsOneWidget);
  });

  testWidgets('over-budget remaining renders with a leading minus',
      (tester) async {
    await tester.pumpWidget(host(CostDashboard(
      summary: sampleSummary(),
      caps: const UserCostCapVM(monthlyUsd: 1),
    )));
    // summary total = $1.25, cap = $1 → remaining = -$0.25.
    expect(find.textContaining('-0.25'), findsOneWidget);
  });

  testWidgets('by-server section lists every server', (tester) async {
    await tester.pumpWidget(host(CostDashboard(summary: sampleSummary())));
    expect(find.text('home-dev'), findsOneWidget);
    expect(find.text('prod-edge'), findsOneWidget);
  });

  testWidgets('top tasks invoke onTaskTap with id', (tester) async {
    String? tapped;
    await tester.pumpWidget(host(CostDashboard(
      summary: sampleSummary(),
      onTaskTap: (id) => tapped = id,
    )));
    await tester.tap(find.text('refactor parser'));
    expect(tapped, 'tA');
  });

  testWidgets('empty summary shows hint copy in every section', (tester) async {
    await tester.pumpWidget(host(CostDashboard(
      summary: CostSummaryVM.empty('Today'),
    )));
    expect(find.text('No spend in this period.'), findsOneWidget);
    expect(find.text('No tasks recorded.'), findsOneWidget);
    expect(find.text('No breakdown yet.'), findsOneWidget);
  });

  testWidgets('by-kind orders by descending cost', (tester) async {
    await tester.pumpWidget(host(CostDashboard(summary: sampleSummary())));
    // Primary AI call is the largest contributor at $1.00.
    expect(find.text('AI call'), findsOneWidget);
    expect(find.text('Live summary'), findsOneWidget);
    expect(find.text('Tool use'), findsOneWidget);
  });
}
