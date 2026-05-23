import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/widgets/bottom_bar.dart';

import 'test_helpers.dart';

List<BottomBarItem> _items() => [
      const BottomBarItem(
        icon: Text('T'),
        activeIcon: Text('T!'),
        label: 'Terminal',
      ),
      const BottomBarItem(
        icon: Text('F'),
        activeIcon: Text('F!'),
        label: 'Files',
        badgeCount: 3,
      ),
      const BottomBarItem(
        icon: Text('A'),
        activeIcon: Text('A!'),
        label: 'AI',
      ),
      const BottomBarItem(
        icon: Text('S'),
        activeIcon: Text('S!'),
        label: 'Settings',
      ),
    ];

void main() {
  group('TermexBottomBar', () {
    testWidgets('renders all item labels', (tester) async {
      await tester.pumpWidget(wrapWidget(
        TermexBottomBar(
          items: _items(),
          selectedIndex: 0,
          onTap: (_) {},
        ),
      ));
      expect(find.text('Terminal'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('onTap fires with correct index', (tester) async {
      int tapped = -1;
      await tester.pumpWidget(wrapWidget(
        TermexBottomBar(
          items: _items(),
          selectedIndex: 0,
          onTap: (i) => tapped = i,
        ),
      ));
      await tester.tap(find.text('Files'));
      expect(tapped, 1);
    });

    testWidgets('onTap fires index 2 for AI', (tester) async {
      int tapped = -1;
      await tester.pumpWidget(wrapWidget(
        TermexBottomBar(
          items: _items(),
          selectedIndex: 0,
          onTap: (i) => tapped = i,
        ),
      ));
      await tester.tap(find.text('AI'));
      expect(tapped, 2);
    });

    testWidgets('renders without overflow', (tester) async {
      await tester.pumpWidget(wrapWidget(
        TermexBottomBar(
          items: _items(),
          selectedIndex: 1,
          onTap: (_) {},
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('selected index changes do not throw', (tester) async {
      int sel = 0;
      late StateSetter setStateFn;
      await tester.pumpWidget(wrapWidget(
        StatefulBuilder(
          builder: (ctx, setState) {
            setStateFn = setState;
            return TermexBottomBar(
              items: _items(),
              selectedIndex: sel,
              onTap: (i) => setState(() => sel = i),
            );
          },
        ),
      ));
      setStateFn(() => sel = 2);
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    });
  });
}
