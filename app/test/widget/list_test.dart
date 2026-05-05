import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/list.dart';

import 'test_helpers.dart';

void main() {
  group('TermexList', () {
    testWidgets('renders all items', (tester) async {
      final servers = ['prod-01', 'dev-02', 'staging-03'];
      await tester.pumpWidget(
        wrapWidget(
          SizedBox(
            height: 300,
            child: TermexList<String>(
              items: servers,
              virtualScroll: false,
              itemBuilder: (_, s, __) => Text(s, key: ValueKey(s)),
            ),
          ),
        ),
      );
      await tester.pump();
      for (final s in servers) {
        expect(find.text(s), findsOneWidget);
      }
    });

    testWidgets('shows emptyWidget when items is empty', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          SizedBox(
            height: 300,
            child: TermexList<String>(
              items: const [],
              itemBuilder: (_, s, __) => Text(s),
              emptyWidget: const Text('No servers'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('No servers'), findsOneWidget);
    });
  });

  group('TermexListTile', () {
    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const TermexListTile(
            title: 'prod-01',
            subtitle: '192.168.1.1',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('prod-01'), findsOneWidget);
      expect(find.text('192.168.1.1'), findsOneWidget);
    });

    testWidgets('fires onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        wrapWidget(
          TermexListTile(
            title: 'prod-01',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(TermexListTile));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('does not fire onTap when disabled', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        wrapWidget(
          TermexListTile(
            title: 'prod-01',
            disabled: true,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(TermexListTile));
      await tester.pump();
      expect(tapped, isFalse);
    });
  });
}
