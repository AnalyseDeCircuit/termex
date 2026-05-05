import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/card.dart';

import 'test_helpers.dart';

void main() {
  group('TermexCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const TermexCard(
            child: Text('card content'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('card content'), findsOneWidget);
    });

    testWidgets('renders title when provided', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const TermexCard(
            title: 'Server Details',
            child: Text('card content'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Server Details'), findsOneWidget);
      expect(find.text('card content'), findsOneWidget);
    });

    testWidgets('renders without title', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const TermexCard(
            child: Text('no title here'),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('no title here'), findsOneWidget);
    });
  });
}
