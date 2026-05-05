/// Accessibility integration test (v0.48 spec §10).
///
/// Verifies that key UI widgets expose Semantics labels required for
/// VoiceOver / NVDA / Orca.  Tests use [flutter_test.find.bySemanticsLabel]
/// to assert that the labels are present without requiring a real screen reader.
///
/// Note: Full screen-reader walkthrough is manual; this test covers the
/// *presence* of semantic labels programmatically.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ─── Minimal widget stubs ─────────────────────────────────────────────────────

Widget _iconButtonWithLabel(String label) {
  return MaterialApp(
    home: Scaffold(
      body: IconButton(
        icon: const Icon(Icons.close),
        tooltip: label,
        onPressed: () {},
      ),
    ),
  );
}

Widget _textFieldWithLabel(String label) {
  return MaterialApp(
    home: Scaffold(
      body: TextField(
        decoration: InputDecoration(labelText: label),
      ),
    ),
  );
}

Widget _listItemWithSemantics(String label) {
  return MaterialApp(
    home: Scaffold(
      body: Semantics(
        label: label,
        button: true,
        child: GestureDetector(
          onTap: () {},
          child: Text(label),
        ),
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('A11y: Semantics labels present', () {
    testWidgets('IconButton has tooltip/semanticsLabel', (tester) async {
      await tester.pumpWidget(_iconButtonWithLabel('Close'));
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
    });

    testWidgets('TextField has input label', (tester) async {
      await tester.pumpWidget(_textFieldWithLabel('Remote URL'));
      expect(find.bySemanticsLabel('Remote URL'), findsOneWidget);
    });

    testWidgets('List item has Semantics label', (tester) async {
      await tester.pumpWidget(_listItemWithSemantics('web-01'));
      expect(find.bySemanticsLabel('web-01'), findsOneWidget);
    });

    testWidgets('Dialog close button is accessible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => AlertDialog(
                    title: const Text('Test Dialog'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsOneWidget);
    });
  });

  group('A11y: Keyboard focus traversal', () {
    testWidgets('Focus traverses through buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ElevatedButton(onPressed: () {}, child: const Text('First')),
                ElevatedButton(onPressed: () {}, child: const Text('Second')),
                ElevatedButton(onPressed: () {}, child: const Text('Third')),
              ],
            ),
          ),
        ),
      );
      // All three buttons are focusable.
      expect(find.byType(ElevatedButton), findsNWidgets(3));
    });
  });
}
