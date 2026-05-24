import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/cost/model/cost_view_model.dart';
import 'package:termex_shared/features/cost/widgets/cost_cap_dialog.dart';

Widget host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 600)),
        child: child,
      ),
    );

void main() {
  testWidgets('renders all three cap labels + buttons', (tester) async {
    await tester.pumpWidget(host(CostCapDialog(
      initial: const UserCostCapVM(),
      onSave: (_) {},
      onCancel: () {},
    )));
    expect(find.textContaining('Monthly cap'), findsOneWidget);
    expect(find.textContaining('Per single task'), findsOneWidget);
    expect(find.textContaining('Per server'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('cancel invokes the cancel callback', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(host(CostCapDialog(
      initial: const UserCostCapVM(),
      onSave: (_) {},
      onCancel: () => cancelled = true,
    )));
    await tester.tap(find.text('Cancel'));
    expect(cancelled, isTrue);
  });

  testWidgets('save returns the initial caps when nothing edited',
      (tester) async {
    UserCostCapVM? out;
    await tester.pumpWidget(host(CostCapDialog(
      initial: const UserCostCapVM(monthlyUsd: 10, singleTaskUsd: 1),
      onSave: (v) => out = v,
      onCancel: () {},
    )));
    await tester.tap(find.text('Save'));
    expect(out, isNotNull);
    expect(out!.monthlyUsd, 10);
    expect(out!.singleTaskUsd, 1);
    expect(out!.perServerUsd, isNull);
  });
}
