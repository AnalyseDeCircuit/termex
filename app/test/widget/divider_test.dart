import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/divider.dart';

import 'test_helpers.dart';

void main() {
  group('TermexDivider', () {
    testWidgets('horizontal divider renders', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const SizedBox(
            width: 200,
            child: TermexDivider(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TermexDivider), findsOneWidget);
    });

    testWidgets('vertical divider renders', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const SizedBox(
            height: 200,
            child: TermexDivider(direction: Axis.vertical),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TermexDivider), findsOneWidget);
    });
  });
}
