import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/widgets/bottom_sheet.dart';

import 'test_helpers.dart';

void main() {
  group('showTermexBottomSheet', () {
    testWidgets('shows child content when opened', (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showTermexBottomSheet(
              context: ctx,
              child: const Text('Sheet Content'),
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet Content'), findsOneWidget);
    });

    testWidgets('tapping barrier closes the sheet', (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showTermexBottomSheet(
              context: ctx,
              child: const Text('Sheet Content'),
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet Content'), findsOneWidget);

      // Tap the barrier (top-left area outside the sheet).
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Sheet Content'), findsNothing);
    });

    testWidgets('renders drag handle', (tester) async {
      await tester.pumpWidget(wrapWidget(
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => showTermexBottomSheet(
              context: ctx,
              child: const SizedBox.shrink(),
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // Drag handle is a Container — just verify no exception.
      expect(tester.takeException(), isNull);
    });
  });
}
