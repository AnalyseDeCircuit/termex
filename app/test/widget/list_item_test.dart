import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/widgets/list_item.dart';

import 'test_helpers.dart';

void main() {
  group('TermexListItem', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexListItem(title: 'prod-server'),
      ));
      expect(find.text('prod-server'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexListItem(title: 'server', subtitle: '192.168.1.1'),
      ));
      expect(find.text('192.168.1.1'), findsOneWidget);
    });

    testWidgets('fires onTap when tapped', (tester) async {
      bool fired = false;
      await tester.pumpWidget(wrapWidget(
        TermexListItem(title: 'server', onTap: () => fired = true),
      ));
      await tester.tap(find.byType(TermexListItem));
      await tester.pumpAndSettle();
      expect(fired, isTrue);
    });

    testWidgets('does not fire onTap when disabled', (tester) async {
      bool fired = false;
      await tester.pumpWidget(wrapWidget(
        TermexListItem(
          title: 'server',
          disabled: true,
          onTap: () => fired = true,
        ),
      ));
      await tester.tap(find.byType(TermexListItem));
      expect(fired, isFalse);
    });

    testWidgets('renders trailing widget', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexListItem(
          title: 'server',
          trailing: Text('chevron'),
        ),
      ));
      expect(find.text('chevron'), findsOneWidget);
    });

    testWidgets('renders leading widget', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexListItem(
          title: 'server',
          leading: Text('icon'),
        ),
      ));
      expect(find.text('icon'), findsOneWidget);
    });

    testWidgets('meets 44pt min touch target height', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexListItem(title: 'server', onTap: null),
      ));
      final size = tester.getSize(find.byType(TermexListItem));
      expect(size.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('selected state renders without error', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexListItem(title: 'server', selected: true),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('press animation runs without error', (tester) async {
      await tester.pumpWidget(wrapWidget(
        TermexListItem(title: 'server', onTap: () {}),
      ));
      await tester.press(find.byType(TermexListItem));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  });
}
