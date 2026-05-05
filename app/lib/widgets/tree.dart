import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

class TreeNode<T> {
  final String key;
  final T data;
  final List<TreeNode<T>>? children;
  final bool leaf;

  const TreeNode({
    required this.key,
    required this.data,
    this.children,
    this.leaf = false,
  });
}

class TermexTree<T> extends StatefulWidget {
  final List<TreeNode<T>> nodes;
  final Widget Function(BuildContext, T, bool selected) nodeBuilder;
  final Set<String> expandedKeys;
  final ValueChanged<String>? onToggleExpand;
  final ValueChanged<T>? onSelect;
  final String? selectedKey;
  final bool virtualScroll;

  const TermexTree({
    super.key,
    required this.nodes,
    required this.nodeBuilder,
    required this.expandedKeys,
    this.onToggleExpand,
    this.onSelect,
    this.selectedKey,
    this.virtualScroll = true,
  });

  @override
  State<TermexTree<T>> createState() => _TermexTreeState<T>();
}

class _FlatNode<T> {
  final TreeNode<T> node;
  final int depth;

  const _FlatNode({required this.node, required this.depth});
}

class _TermexTreeState<T> extends State<TermexTree<T>> {
  List<_FlatNode<T>> _flatten(List<TreeNode<T>> nodes, int depth) {
    final result = <_FlatNode<T>>[];
    for (final node in nodes) {
      result.add(_FlatNode(node: node, depth: depth));
      if (!node.leaf &&
          node.children != null &&
          widget.expandedKeys.contains(node.key)) {
        result.addAll(_flatten(node.children!, depth + 1));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final flat = _flatten(widget.nodes, 0);
    return ListView.builder(
      itemCount: flat.length,
      itemBuilder: (context, i) {
        final item = flat[i];
        final isSelected = item.node.key == widget.selectedKey;
        return _TreeRow<T>(
          flatNode: item,
          isSelected: isSelected,
          isExpanded: widget.expandedKeys.contains(item.node.key),
          nodeBuilder: widget.nodeBuilder,
          onToggleExpand: widget.onToggleExpand,
          onSelect: widget.onSelect,
        );
      },
    );
  }
}

class _TreeRow<T> extends StatefulWidget {
  final _FlatNode<T> flatNode;
  final bool isSelected;
  final bool isExpanded;
  final Widget Function(BuildContext, T, bool selected) nodeBuilder;
  final ValueChanged<String>? onToggleExpand;
  final ValueChanged<T>? onSelect;

  const _TreeRow({
    super.key,
    required this.flatNode,
    required this.isSelected,
    required this.isExpanded,
    required this.nodeBuilder,
    this.onToggleExpand,
    this.onSelect,
  });

  @override
  State<_TreeRow<T>> createState() => _TreeRowState<T>();
}

class _TreeRowState<T> extends State<_TreeRow<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: widget.isExpanded ? 1.0 : 0.0,
    );
    _rotation = Tween<double>(begin: 0, end: 0.25).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_TreeRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _rotationController.forward();
      } else {
        _rotationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.flatNode.node;
    final depth = widget.flatNode.depth;
    final hasChildren = !node.leaf && (node.children?.isNotEmpty ?? false);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelect?.call(node.data),
      child: Padding(
        padding: EdgeInsets.only(left: depth * 20.0),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: hasChildren
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onToggleExpand?.call(node.key),
                      child: Center(
                        child: RotationTransition(
                          turns: _rotation,
                          child: const _TriangleIcon(),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: widget.nodeBuilder(context, node.data, widget.isSelected),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriangleIcon extends StatelessWidget {
  const _TriangleIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(8, 8),
      painter: _TrianglePainter(),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TermexColors.textSecondary
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
