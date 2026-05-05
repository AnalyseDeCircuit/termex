import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/text_field.dart';
import 'package:termex/widgets/form_validators.dart';

import 'test_helpers.dart';

void main() {
  group('TermexTextField', () {
    testWidgets('renders placeholder when empty', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexTextField(placeholder: 'Enter hostname'),
      ));
      expect(find.text('Enter hostname'), findsOneWidget);
    });

    testWidgets('notifies onChanged on input', (tester) async {
      String? changed;
      await tester.pumpWidget(wrapWidget(
        TermexTextField(onChanged: (v) => changed = v),
      ));
      await tester.enterText(find.byType(TermexTextField), 'hello');
      expect(changed, equals('hello'));
    });

    testWidgets('shows errorText when provided', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexTextField(errorText: 'Required'),
      ));
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('shows label when provided', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const TermexTextField(label: 'Hostname'),
      ));
      expect(find.text('Hostname'), findsOneWidget);
    });

    testWidgets('runs validators and shows error on empty required field', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(wrapWidget(
        TermexTextField(
          controller: controller,
          validators: [Validators.required()],
        ),
      ));
      // Type and clear to trigger validation
      await tester.enterText(find.byType(TermexTextField), 'x');
      await tester.enterText(find.byType(TermexTextField), '');
      await tester.pump();
      expect(find.text('此项为必填'), findsOneWidget);
    });

    testWidgets('does not accept input when disabled', (tester) async {
      String? changed;
      await tester.pumpWidget(wrapWidget(
        TermexTextField(disabled: true, onChanged: (v) => changed = v),
      ));
      await tester.enterText(find.byType(TermexTextField), 'hello');
      expect(changed, isNull);
    });
  });
}
