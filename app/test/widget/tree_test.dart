import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/tree.dart';

import 'test_helpers.dart';

TreeNode<String> _leaf(String key, String data) =>
    TreeNode(key: key, data: data, leaf: true);

final _nodes = [
  TreeNode(
    key: 'servers',
    data: 'Servers',
    children: [
      _leaf('prod', 'Production'),
      _leaf('dev', 'Development'),
    ],
  ),
  _leaf('keys', 'SSH Keys'),
];

Widget _nodeBuilder(BuildContext ctx, String data, bool selected) =>
    Text(data, key: ValueKey(data));

void main() {
  group('TermexTree', () {
    testWidgets('renders root nodes', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          TermexTree<String>(
            nodes: _nodes,
            nodeBuilder: _nodeBuilder,
            expandedKeys: const {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Servers'), findsOneWidget);
      expect(find.text('SSH Keys'), findsOneWidget);
    });

    testWidgets('does not render children of collapsed node', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          TermexTree<String>(
            nodes: _nodes,
            nodeBuilder: _nodeBuilder,
            expandedKeys: const {}, // 'servers' not expanded
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Production'), findsNothing);
      expect(find.text('Development'), findsNothing);
    });

    testWidgets('calls onToggleExpand when expand triangle tapped', (tester) async {
      String? toggled;
      await tester.pumpWidget(
        wrapWidget(
          TermexTree<String>(
            nodes: _nodes,
            nodeBuilder: _nodeBuilder,
            expandedKeys: const {},
            onToggleExpand: (key) => toggled = key,
          ),
        ),
      );
      await tester.pump();
      // Tap the chevron (10px to the left of the 'Servers' label).
      final labelPos = tester.getTopLeft(find.text('Servers'));
      await tester.tapAt(Offset(labelPos.dx - 10, labelPos.dy + 8));
      await tester.pump();
      expect(toggled, equals('servers'));
    });

    testWidgets('calls onSelect when node tapped', (tester) async {
      String? selected;
      await tester.pumpWidget(
        wrapWidget(
          TermexTree<String>(
            nodes: [_leaf('keys', 'SSH Keys')],
            nodeBuilder: _nodeBuilder,
            expandedKeys: const {},
            onSelect: (data) => selected = data,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('SSH Keys'));
      await tester.pump();
      expect(selected, equals('SSH Keys'));
    });
  });
}
