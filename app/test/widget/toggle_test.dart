import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/toggle.dart';

import 'test_helpers.dart';

void main() {
  group('TermexToggle', () {
    testWidgets('fires onChanged when tapped', (tester) async {
      bool? changedTo;
      await tester.pumpWidget(
        wrapWidget(
          TermexToggle(
            value: false,
            onChanged: (v) => changedTo = v,
          ),
        ),
      );
      await tester.tap(find.byType(TermexToggle));
      await tester.pump();
      expect(changedTo, isNotNull);
    });

    testWidgets('does not fire when disabled', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        wrapWidget(
          TermexToggle(
            value: false,
            disabled: true,
            onChanged: (_) => called = true,
          ),
        ),
      );
      await tester.tap(find.byType(TermexToggle));
      await tester.pump();
      expect(called, isFalse);
    });

    testWidgets('toggles value on tap — onChanged called with true', (tester) async {
      bool? received;
      await tester.pumpWidget(
        wrapWidget(
          TermexToggle(
            value: false,
            onChanged: (v) => received = v,
          ),
        ),
      );
      await tester.tap(find.byType(TermexToggle));
      await tester.pump();
      expect(received, isTrue);
    });
  });
}
