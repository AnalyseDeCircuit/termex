import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/widgets/segmented.dart';

import 'test_helpers.dart';

void main() {
  group('TermexSegmented', () {
    testWidgets('renders all item labels', (tester) async {
      await tester.pumpWidget(wrapWidget(
        TermexSegmented(
          items: const ['SSH', 'SFTP', 'AI'],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('SSH'), findsOneWidget);
      expect(find.text('SFTP'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
    });

    testWidgets('onChanged fires with correct index when tapping second item', (tester) async {
      int changed = -1;
      await tester.pumpWidget(wrapWidget(
        TermexSegmented(
          items: const ['SSH', 'SFTP', 'AI'],
          selectedIndex: 0,
          onChanged: (i) => changed = i,
        ),
      ));
      await tester.tap(find.text('SFTP'));
      expect(changed, 1);
    });

    testWidgets('onChanged fires index 2 for third item', (tester) async {
      int changed = -1;
      await tester.pumpWidget(wrapWidget(
        TermexSegmented(
          items: const ['SSH', 'SFTP', 'AI'],
          selectedIndex: 0,
          onChanged: (i) => changed = i,
        ),
      ));
      await tester.tap(find.text('AI'));
      expect(changed, 2);
    });

    testWidgets('renders without overflow', (tester) async {
      await tester.pumpWidget(wrapWidget(
        TermexSegmented(
          items: const ['A', 'B', 'C', 'D'],
          selectedIndex: 2,
          onChanged: (_) {},
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('animation runs when selectedIndex changes', (tester) async {
      int sel = 0;
      late StateSetter setStateFn;
      await tester.pumpWidget(wrapWidget(
        StatefulBuilder(
          builder: (ctx, setState) {
            setStateFn = setState;
            return TermexSegmented(
              items: const ['SSH', 'SFTP', 'AI'],
              selectedIndex: sel,
              onChanged: (i) => setState(() => sel = i),
            );
          },
        ),
      ));
      setStateFn(() => sel = 1);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
