import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/radio.dart';

import 'test_helpers.dart';

void main() {
  group('TermexRadio', () {
    testWidgets('fires onChanged with value when tapped', (tester) async {
      String? received;
      await tester.pumpWidget(
        wrapWidget(
          TermexRadio<String>(
            value: 'a',
            groupValue: 'b',
            onChanged: (v) => received = v,
          ),
        ),
      );
      await tester.tap(find.byType(TermexRadio<String>));
      await tester.pump();
      expect(received, equals('a'));
    });

    testWidgets('does not fire when already selected (groupValue == value)', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        wrapWidget(
          TermexRadio<String>(
            value: 'a',
            groupValue: 'a',
            onChanged: (_) => called = true,
          ),
        ),
      );
      await tester.tap(find.byType(TermexRadio<String>));
      await tester.pump();
      expect(called, isFalse);
    });

    testWidgets('does not fire when disabled', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        wrapWidget(
          TermexRadio<String>(
            value: 'a',
            groupValue: 'b',
            disabled: true,
            onChanged: (_) => called = true,
          ),
        ),
      );
      await tester.tap(find.byType(TermexRadio<String>));
      await tester.pump();
      expect(called, isFalse);
    });
  });
}
