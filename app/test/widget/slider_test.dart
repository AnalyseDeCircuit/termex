import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/slider.dart';

import 'test_helpers.dart';

void main() {
  group('TermexSlider', () {
    testWidgets('renders without overflow', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          SizedBox(
            width: 300,
            child: TermexSlider(
              value: 0.5,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TermexSlider), findsOneWidget);
    });

    testWidgets('renders with divisions', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          SizedBox(
            width: 300,
            child: TermexSlider(
              value: 0.5,
              divisions: 10,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TermexSlider), findsOneWidget);
    });

    testWidgets('renders disabled', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          SizedBox(
            width: 300,
            child: TermexSlider(
              value: 0.3,
              disabled: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TermexSlider), findsOneWidget);
    });
  });
}
