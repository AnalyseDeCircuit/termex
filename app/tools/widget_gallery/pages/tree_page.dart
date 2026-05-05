import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';
import 'package:termex/widgets/tree.dart';

class _ServerData {
  final String name;
  final bool isGroup;

  const _ServerData({required this.name, this.isGroup = false});
}

class TreePage extends StatefulWidget {
  const TreePage({super.key});

  @override
  State<TreePage> createState() => _TreePageState();
}

class _TreePageState extends State<TreePage> {
  Set<String> _expandedKeys = {'group-a', 'group-b'};
  String? _selectedKey;

  static final _nodes = [
    TreeNode<_ServerData>(
      key: 'group-a',
      data: const _ServerData(name: 'Group A', isGroup: true),
      children: [
        TreeNode<_ServerData>(
          key: 'server-1',
          data: const _ServerData(name: 'server-1'),
          leaf: true,
        ),
        TreeNode<_ServerData>(
          key: 'server-2',
          data: const _ServerData(name: 'server-2'),
          leaf: true,
        ),
      ],
    ),
    TreeNode<_ServerData>(
      key: 'group-b',
      data: const _ServerData(name: 'Group B', isGroup: true),
      children: [
        TreeNode<_ServerData>(
          key: 'server-3',
          data: const _ServerData(name: 'server-3'),
          leaf: true,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tree',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Server Group Hierarchy',
            child: SizedBox(
              height: 280,
              child: TermexTree<_ServerData>(
                nodes: _nodes,
                expandedKeys: _expandedKeys,
                selectedKey: _selectedKey,
                onToggleExpand: (key) {
                  setState(() {
                    if (_expandedKeys.contains(key)) {
                      _expandedKeys = Set.from(_expandedKeys)..remove(key);
                    } else {
                      _expandedKeys = Set.from(_expandedKeys)..add(key);
                    }
                  });
                },
                onSelect: (data) {
                  setState(() => _selectedKey = data.name);
                },
                nodeBuilder: (ctx, data, selected) => _NodeItem(
                  data: data,
                  selected: selected,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeItem extends StatelessWidget {
  final _ServerData data;
  final bool selected;

  const _NodeItem({required this.data, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: selected ? TermexColors.backgroundTertiary : null,
        borderRadius: TermexRadius.sm,
      ),
      child: Row(
        children: [
          if (data.isGroup)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FolderIcon(open: true),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _ServerIcon(),
            ),
          Text(
            data.name,
            style: TermexTypography.body.copyWith(
              color: selected
                  ? TermexColors.textPrimary
                  : TermexColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderIcon extends StatelessWidget {
  final bool open;

  const _FolderIcon({required this.open});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(painter: _FolderPainter(open: open)),
    );
  }
}

class _FolderPainter extends CustomPainter {
  final bool open;

  const _FolderPainter({required this.open});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TermexColors.warning
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height * 0.35)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height * 0.35)
      ..close();
    canvas.drawPath(path, paint);

    final tab = Path()
      ..moveTo(0, size.height * 0.35)
      ..lineTo(size.width * 0.4, size.height * 0.35)
      ..lineTo(size.width * 0.5, size.height * 0.2)
      ..lineTo(0, size.height * 0.2)
      ..close();
    canvas.drawPath(tab, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ServerIcon extends StatelessWidget {
  const _ServerIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(painter: _ServerPainter()),
    );
  }
}

class _ServerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TermexColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(2),
    );
    canvas.drawRRect(rect, paint);
    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.4),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TermexTypography.heading4.copyWith(
            color: TermexColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
