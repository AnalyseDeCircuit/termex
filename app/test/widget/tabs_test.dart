import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/tabs.dart';

import 'test_helpers.dart';

final _tabs = [
  const TabItem(label: 'Servers'),
  const TabItem(label: 'Sessions'),
  const TabItem(label: 'Keys'),
];

void main() {
  group('TermexTabs', () {
    testWidgets('renders all tab labels', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          TermexTabs(
            tabs: _tabs,
            activeIndex: 0,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Servers'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Keys'), findsOneWidget);
    });

    testWidgets('fires onChanged with correct index on tap', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        wrapWidget(
          TermexTabs(
            tabs: _tabs,
            activeIndex: 0,
            onChanged: (i) => tapped = i,
          ),
        ),
      );
      await tester.tap(find.text('Sessions'));
      await tester.pump();
      expect(tapped, equals(1));
    });

    testWidgets('all three variants render without overflow', (tester) async {
      for (final variant in TabVariant.values) {
        await tester.pumpWidget(
          wrapWidget(
            TermexTabs(
              tabs: _tabs,
              activeIndex: 0,
              onChanged: (_) {},
              variant: variant,
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'variant $variant threw an exception');
      }
    });
  });
}
