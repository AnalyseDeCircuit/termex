import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/features/cost/widgets/cost_chip.dart';

Widget host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(375, 700)),
        child: Center(child: child),
      ),
    );

/// Pull the Text color out of the chip directly — the chip's label
/// is the only Text in the tree, and its color tracks the same
/// computed `_chipColor` used by the surrounding container border.
Color _labelColor(WidgetTester tester) {
  final text = tester.widget<Text>(find.byType(Text));
  return text.style!.color!;
}

void main() {
  testWidgets('renders dollar + token labels', (tester) async {
    await tester.pumpWidget(host(const CostChip(
      costUsd: 1.25,
      totalTokens: 8400,
    )));
    expect(find.text('\$1.25 · 8.4K tok'), findsOneWidget);
  });

  testWidgets('formats sub-cent dust amounts', (tester) async {
    await tester.pumpWidget(host(const CostChip(
      costUsd: 0.0005,
      totalTokens: 1,
    )));
    expect(find.textContaining('\$0.0005'), findsOneWidget);
  });

  testWidgets('neutral color when no cap supplied', (tester) async {
    await tester.pumpWidget(host(const CostChip(
      costUsd: 5.0,
      totalTokens: 100,
    )));
    expect(_labelColor(tester), TermexColors.textSecondary);
  });

  testWidgets('warning color at 75-99% of cap', (tester) async {
    await tester.pumpWidget(host(const CostChip(
      costUsd: 0.80,
      totalTokens: 100,
      singleTaskCapUsd: 1.00,
    )));
    expect(_labelColor(tester), TermexColors.warning);
  });

  testWidgets('danger color when at-or-over cap', (tester) async {
    await tester.pumpWidget(host(const CostChip(
      costUsd: 1.00,
      totalTokens: 100,
      singleTaskCapUsd: 1.00,
    )));
    expect(_labelColor(tester), TermexColors.danger);
  });
}
