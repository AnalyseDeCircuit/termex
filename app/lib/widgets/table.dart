import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

enum SortDirection { none, asc, desc }

class TermexColumn<T> {
  final String id;
  final String label;
  final double? width;
  final Widget Function(BuildContext, T) cellBuilder;
  final bool sortable;

  const TermexColumn({
    required this.id,
    required this.label,
    this.width,
    required this.cellBuilder,
    this.sortable = false,
  });
}

class TermexDataTable<T> extends StatelessWidget {
  final List<TermexColumn<T>> columns;
  final List<T> rows;
  final bool sortable;
  final String? sortColumnId;
  final SortDirection sortDirection;
  final ValueChanged<String>? onSortChanged;
  final bool selectable;
  final Set<int>? selectedRows;
  final ValueChanged<Set<int>>? onSelectionChanged;
  final Widget? emptyWidget;
  final bool stickyHeader;

  const TermexDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.sortable = false,
    this.sortColumnId,
    this.sortDirection = SortDirection.none,
    this.onSortChanged,
    this.selectable = false,
    this.selectedRows,
    this.onSelectionChanged,
    this.emptyWidget,
    this.stickyHeader = true,
  });

  bool get _allSelected =>
      rows.isNotEmpty &&
      selectedRows != null &&
      selectedRows!.length == rows.length;

  bool get _someSelected =>
      selectedRows != null &&
      selectedRows!.isNotEmpty &&
      selectedRows!.length < rows.length;

  void _toggleAll() {
    if (onSelectionChanged == null) return;
    if (_allSelected) {
      onSelectionChanged!({});
    } else {
      onSelectionChanged!({for (var i = 0; i < rows.length; i++) i});
    }
  }

  void _toggleRow(int index) {
    if (onSelectionChanged == null || selectedRows == null) return;
    final next = Set<int>.from(selectedRows!);
    if (next.contains(index)) {
      next.remove(index);
    } else {
      next.add(index);
    }
    onSelectionChanged!(next);
  }

  Widget _buildHeaderCell(BuildContext context, TermexColumn<T> col) {
    final isSorted = sortColumnId == col.id;
    final canSort = sortable && col.sortable;

    Widget label = Text(
      col.label.toUpperCase(),
      style: TermexTypography.bodySmall.copyWith(
        color: TermexColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );

    if (isSorted && sortDirection != SortDirection.none) {
      label = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          label,
          const SizedBox(width: 4),
          Text(
            sortDirection == SortDirection.asc ? '↑' : '↓',
            style: TermexTypography.bodySmall.copyWith(
              color: TermexColors.primary,
            ),
          ),
        ],
      );
    }

    Widget cell = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TermexSpacing.md,
        vertical: TermexSpacing.sm,
      ),
      child: label,
    );

    if (canSort) {
      cell = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSortChanged?.call(col.id),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: cell,
        ),
      );
    }

    if (col.width != null) {
      return SizedBox(width: col.width, child: cell);
    }
    return Expanded(child: cell);
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: TermexColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (selectable)
            SizedBox(
              width: 40,
              child: Center(
                child: _HeaderCheckbox(
                  checked: _allSelected,
                  indeterminate: _someSelected,
                  onTap: _toggleAll,
                ),
              ),
            ),
          ...columns.map((col) => _buildHeaderCell(context, col)),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    final row = rows[index];
    final isSelected = selectedRows?.contains(index) ?? false;

    return _DataRow(
      key: ValueKey(index),
      columns: columns,
      rowData: row,
      index: index,
      isSelected: isSelected,
      selectable: selectable,
      onToggle: () => _toggleRow(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && emptyWidget != null) {
      return Column(
        children: [
          _buildHeader(context),
          Expanded(child: Center(child: emptyWidget!)),
        ],
      );
    }

    if (stickyHeader) {
      return CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _TableHeaderDelegate(
              height: 40,
              child: _buildHeader(context),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildRow(ctx, i),
              childCount: rows.length,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: _buildRow,
          ),
        ),
      ],
    );
  }
}

class _DataRow<T> extends StatefulWidget {
  final List<TermexColumn<T>> columns;
  final T rowData;
  final int index;
  final bool isSelected;
  final bool selectable;
  final VoidCallback onToggle;

  const _DataRow({
    super.key,
    required this.columns,
    required this.rowData,
    required this.index,
    required this.isSelected,
    required this.selectable,
    required this.onToggle,
  });

  @override
  State<_DataRow<T>> createState() => _DataRowState<T>();
}

class _DataRowState<T> extends State<_DataRow<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0x00000000);
    if (widget.isSelected || _hovered) {
      bg = TermexColors.backgroundTertiary;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        height: 40,
        color: bg,
        child: Row(
          children: [
            if (widget.selectable)
              SizedBox(
                width: 40,
                child: Center(
                  child: _RowCheckbox(
                    checked: widget.isSelected,
                    onTap: widget.onToggle,
                  ),
                ),
              ),
            ...widget.columns.map((col) {
              final cell = Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TermexSpacing.md,
                ),
                child: col.cellBuilder(context, widget.rowData),
              );
              if (col.width != null) {
                return SizedBox(width: col.width, child: cell);
              }
              return Expanded(child: cell);
            }),
          ],
        ),
      ),
    );
  }
}

class _HeaderCheckbox extends StatelessWidget {
  final bool checked;
  final bool indeterminate;
  final VoidCallback onTap;

  const _HeaderCheckbox({
    required this.checked,
    required this.indeterminate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: (checked || indeterminate)
              ? TermexColors.primary
              : const Color(0x00000000),
          border: Border.all(
            color: (checked || indeterminate)
                ? TermexColors.primary
                : TermexColors.border,
            width: 1,
          ),
          borderRadius: TermexRadius.sm,
        ),
        child: (checked || indeterminate)
            ? CustomPaint(painter: _CheckmarkPainter(indeterminate: indeterminate))
            : null,
      ),
    );
  }
}

class _RowCheckbox extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;

  const _RowCheckbox({required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: checked ? TermexColors.primary : const Color(0x00000000),
          border: Border.all(
            color: checked ? TermexColors.primary : TermexColors.border,
            width: 1,
          ),
          borderRadius: TermexRadius.sm,
        ),
        child: checked
            ? CustomPaint(painter: _CheckmarkPainter(indeterminate: false))
            : null,
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final bool indeterminate;
  const _CheckmarkPainter({required this.indeterminate});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (indeterminate) {
      canvas.drawLine(
        Offset(size.width * 0.25, size.height * 0.5),
        Offset(size.width * 0.75, size.height * 0.5),
        paint,
      );
    } else {
      final path = Path()
        ..moveTo(size.width * 0.2, size.height * 0.5)
        ..lineTo(size.width * 0.45, size.height * 0.75)
        ..lineTo(size.width * 0.8, size.height * 0.25);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter old) =>
      old.indeterminate != indeterminate;
}

class _TableHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _TableHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TableHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
}
