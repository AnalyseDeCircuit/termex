import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/checkbox.dart';

import 'test_helpers.dart';

void main() {
  group('TermexCheckbox', () {
    testWidgets('fires onChanged with true when unchecked tapped', (tester) async {
      bool? received;
      await tester.pumpWidget(
        wrapWidget(
          TermexCheckbox(
            value: false,
            onChanged: (v) => received = v,
          ),
        ),
      );
      await tester.tap(find.byType(TermexCheckbox));
      await tester.pump();
      expect(received, isTrue);
    });

    testWidgets('fires onChanged with false when checked tapped', (tester) async {
      bool? received;
      await tester.pumpWidget(
        wrapWidget(
          TermexCheckbox(
            value: true,
            onChanged: (v) => received = v,
          ),
        ),
      );
      await tester.tap(find.byType(TermexCheckbox));
      await tester.pump();
      expect(received, isFalse);
    });

    testWidgets('does not fire when disabled', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        wrapWidget(
          TermexCheckbox(
            value: false,
            disabled: true,
            onChanged: (_) => called = true,
          ),
        ),
      );
      await tester.tap(find.byType(TermexCheckbox));
      await tester.pump();
      expect(called, isFalse);
    });

    testWidgets('renders without overflow for all states', (tester) async {
      for (final v in [null, false, true]) {
        await tester.pumpWidget(
          wrapWidget(
            TermexCheckbox(value: v, tristate: true),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
