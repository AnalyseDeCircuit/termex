import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/button.dart';
import 'package:termex/widgets/checkbox.dart';
import 'package:termex/widgets/toggle.dart';

import 'test_helpers.dart';

void main() {
  group('Button accessibility', () {
    testWidgets('TermexButton has button semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrapWidget(
        TermexButton(label: 'Connect', onPressed: () {}),
      ));
      expect(
        tester.getSemantics(find.byType(TermexButton)),
        matchesSemantics(
          label: 'Connect',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('disabled TermexButton has disabled semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrapWidget(
        TermexButton(label: 'Save', disabled: true, onPressed: () {}),
      ));
      expect(
        tester.getSemantics(find.byType(TermexButton)),
        matchesSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('Checkbox accessibility', () {
    testWidgets('unchecked checkbox has correct semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrapWidget(
        TermexCheckbox(value: false, onChanged: (_) {}),
      ));
      expect(
        tester.getSemantics(find.byType(TermexCheckbox)),
        matchesSemantics(
          hasCheckedState: true,
          isChecked: false,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('checked checkbox has correct semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrapWidget(
        TermexCheckbox(value: true, onChanged: (_) {}),
      ));
      expect(
        tester.getSemantics(find.byType(TermexCheckbox)),
        matchesSemantics(
          hasCheckedState: true,
          isChecked: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('Toggle accessibility', () {
    testWidgets('toggle off has switch semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrapWidget(
        TermexToggle(value: false, onChanged: (_) {}),
      ));
      expect(
        tester.getSemantics(find.byType(TermexToggle)),
        matchesSemantics(
          hasCheckedState: true,
          isChecked: false,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('toggle on has checked semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrapWidget(
        TermexToggle(value: true, onChanged: (_) {}),
      ));
      expect(
        tester.getSemantics(find.byType(TermexToggle)),
        matchesSemantics(
          hasCheckedState: true,
          isChecked: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
