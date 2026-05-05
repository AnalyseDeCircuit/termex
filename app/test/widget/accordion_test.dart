import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/accordion.dart';

import 'test_helpers.dart';

List<AccordionItem> _buildItems() => [
      AccordionItem(
        key: 'connection',
        title: 'Connection',
        contentBuilder: (_) => const Text('Host settings'),
      ),
      AccordionItem(
        key: 'auth',
        title: 'Authentication',
        contentBuilder: (_) => const Text('Key or password'),
      ),
    ];

void main() {
  group('TermexAccordion', () {
    testWidgets('renders item titles', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          TermexAccordion(items: _buildItems()),
        ),
      );
      await tester.pump();
      expect(find.text('Connection'), findsOneWidget);
      expect(find.text('Authentication'), findsOneWidget);
    });

    testWidgets('content not visible when collapsed', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          TermexAccordion(items: _buildItems()),
        ),
      );
      await tester.pump();
      expect(find.text('Host settings'), findsNothing);
      expect(find.text('Key or password'), findsNothing);
    });

    testWidgets('content visible after header tapped', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          TermexAccordion(items: _buildItems()),
        ),
      );
      await tester.tap(find.text('Connection'));
      await tester.pumpAndSettle();
      expect(find.text('Host settings'), findsOneWidget);
    });

    testWidgets('multiple mode allows multiple open', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          TermexAccordion(
            items: _buildItems(),
            multiple: true,
          ),
        ),
      );
      await tester.tap(find.text('Connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Authentication'));
      await tester.pumpAndSettle();
      expect(find.text('Host settings'), findsOneWidget);
      expect(find.text('Key or password'), findsOneWidget);
    });
  });
}
