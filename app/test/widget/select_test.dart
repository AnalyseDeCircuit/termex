import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/select.dart';

import 'test_helpers.dart';

final _options = [
  const SelectOption(value: 'ssh', label: 'SSH'),
  const SelectOption(value: 'sftp', label: 'SFTP'),
  const SelectOption(value: 'telnet', label: 'Telnet'),
];

void main() {
  group('TermexSelect', () {
    testWidgets('renders placeholder when no value', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          TermexSelect<String>(
            options: _options,
            placeholder: 'Choose protocol',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Choose protocol'), findsOneWidget);
    });

    testWidgets('renders selected label when value set', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          TermexSelect<String>(
            options: _options,
            value: 'sftp',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('SFTP'), findsOneWidget);
    });

    testWidgets('opens dropdown on tap', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          TermexSelect<String>(
            options: _options,
            placeholder: 'Choose protocol',
          ),
        ),
      );
      await tester.tap(find.byType(TermexSelect<String>));
      await tester.pumpAndSettle();
      // All option labels should now be visible in the overlay
      expect(find.text('SSH'), findsWidgets);
      expect(find.text('SFTP'), findsWidgets);
      expect(find.text('Telnet'), findsOneWidget);
      // Close dropdown before test ends (tap outside)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    });
  });
}
