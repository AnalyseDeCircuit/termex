import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/button.dart';

import 'test_helpers.dart';

void main() {
  group('TermexButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexButton(label: 'Connect'),
      ));
      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      bool fired = false;
      await tester.pumpWidget(wrapWidget(
        TermexButton(label: 'Go', onPressed: () => fired = true),
      ));
      await tester.tap(find.byType(TermexButton));
      expect(fired, isTrue);
    });

    testWidgets('does not fire onPressed when disabled', (tester) async {
      bool fired = false;
      await tester.pumpWidget(wrapWidget(
        TermexButton(label: 'Go', disabled: true, onPressed: () => fired = true),
      ));
      await tester.tap(find.byType(TermexButton));
      expect(fired, isFalse);
    });

    testWidgets('does not fire when onPressed is null', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexButton(label: 'Noop'),
      ));
      await tester.tap(find.byType(TermexButton));
      // No error = pass
    });

    testWidgets('shows loading indicator when loading=true', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexButton(label: 'Save', loading: true),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('all variants render without overflow', (tester) async {
      for (final variant in ButtonVariant.values) {
        await tester.pumpWidget(wrapWidget(
          TermexButton(label: 'X', variant: variant),
        ));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('all sizes render without overflow', (tester) async {
      for (final size in ButtonSize.values) {
        await tester.pumpWidget(wrapWidget(
          TermexButton(label: 'X', size: size),
        ));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('TermexIconButton', () {
    testWidgets('fires onPressed when tapped', (tester) async {
      bool fired = false;
      await tester.pumpWidget(wrapWidget(
        TermexIconButton(
          icon: const Icon(IconData(0xe5cd, fontFamily: 'MaterialIcons')),
          onPressed: () => fired = true,
        ),
      ));
      await tester.tap(find.byType(TermexIconButton));
      expect(fired, isTrue);
    });

    testWidgets('does not fire when disabled', (tester) async {
      bool fired = false;
      await tester.pumpWidget(wrapWidget(
        TermexIconButton(
          icon: const Icon(IconData(0xe5cd, fontFamily: 'MaterialIcons')),
          disabled: true,
          onPressed: () => fired = true,
        ),
      ));
      await tester.tap(find.byType(TermexIconButton));
      expect(fired, isFalse);
    });
  });
}
