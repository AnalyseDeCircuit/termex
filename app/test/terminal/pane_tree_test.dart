import 'package:flutter_test/flutter_test.dart';
import 'package:termex/terminal/pane/pane_tree.dart';

void main() {
  group('PaneTree', () {
    late PaneTree tree;

    setUp(() {
      tree = PaneTree(root: const PaneLeaf('a'), focusedPaneId: 'a');
    });

    test('initial state has one leaf', () {
      expect(tree.allPaneIds, ['a']);
      expect(tree.hasSplit, isFalse);
    });

    test('splitFocused creates a split with two leaves', () {
      final next = tree.splitFocused('b', SplitAxis.horizontal);
      expect(next.allPaneIds, containsAll(['a', 'b']));
      expect(next.hasSplit, isTrue);
      expect(next.focusedPaneId, 'b');
    });

    test('remove shrinks back to one pane', () {
      final split = tree.splitFocused('b', SplitAxis.vertical);
      final removed = split.remove('b');
      expect(removed.allPaneIds, ['a']);
    });

    test('remove focused pane updates focus to sibling', () {
      final split = tree.splitFocused('b', SplitAxis.horizontal);
      final removed = split.remove('b');
      expect(removed.focusedPaneId, 'a');
    });

    test('withFocus changes focused pane', () {
      final split = tree.splitFocused('b', SplitAxis.horizontal);
      final focused = split.withFocus('a');
      expect(focused.focusedPaneId, 'a');
    });

    test('withFocus ignores unknown pane id', () {
      final unchanged = tree.withFocus('nonexistent');
      expect(unchanged.focusedPaneId, 'a');
    });

    test('updateRatio clamps to [0.15, 0.85]', () {
      final split = tree.splitFocused('b', SplitAxis.horizontal);
      final clamped = split.updateRatio('a', 0.9);
      final splitNode = clamped.root as PaneSplit;
      expect(splitNode.ratio, 0.85);
    });

    test('nested split stores three pane ids', () {
      final s1 = tree.splitFocused('b', SplitAxis.horizontal);
      final s2 = s1.splitFocused('c', SplitAxis.vertical);
      expect(s2.allPaneIds, containsAll(['a', 'b', 'c']));
    });
  });
}
