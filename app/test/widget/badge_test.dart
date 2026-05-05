import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/badge.dart';

import 'test_helpers.dart';

void main() {
  group('TermexBadge', () {
    testWidgets('renders count badge', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const TermexBadge(
            count: 5,
            child: SizedBox(width: 24, height: 24),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows 99+ when count > maxCount', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const TermexBadge(
            count: 120,
            maxCount: 99,
            child: SizedBox(width: 24, height: 24),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('renders dot badge', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const TermexBadge(
            dot: true,
            variant: BadgeVariant.dot,
            child: SizedBox(width: 24, height: 24),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TermexBadge), findsOneWidget);
    });
  });
}
