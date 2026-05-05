/// Recursive pane split view — renders a [PaneTree] as nested widgets.
///
/// Each leaf is rendered by the caller-supplied [paneBuilder]. Internal split
/// nodes render a [_SplitHandle] divider that the user can drag to resize.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../design/colors.dart';
import 'pane_controller.dart';

export 'pane_controller.dart';

/// Renders the full split layout described by [PaneController].
///
/// [paneBuilder] is called with the pane ID to produce its terminal widget.
/// Wrap the terminal tab content in this widget and pass [controller].
class PaneSplitView extends StatelessWidget {
  final PaneController controller;

  /// Called once per leaf pane to build its content.
  final Widget Function(BuildContext context, String paneId) paneBuilder;

  const PaneSplitView({
    super.key,
    required this.controller,
    required this.paneBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return _buildNode(context, controller.tree.root);
      },
    );
  }

  Widget _buildNode(BuildContext context, PaneNode node) {
    return switch (node) {
      PaneLeaf(:final paneId) => _PaneWrapper(
          paneId: paneId,
          isFocused: paneId == controller.focusedPaneId,
          onFocus: () => controller.focusPane(paneId),
          child: paneBuilder(context, paneId),
        ),
      PaneSplit(
        :final axis,
        :final first,
        :final second,
        :final ratio,
      ) =>
        _SplitContainer(
          axis: axis,
          ratio: ratio,
          first: _buildNode(context, first),
          second: _buildNode(context, second),
          onRatioChanged: (r) =>
              controller.updateRatio(_firstLeafId(first), r),
        ),
    };
  }

  String _firstLeafId(PaneNode node) => switch (node) {
        PaneLeaf(:final paneId) => paneId,
        PaneSplit(:final first) => _firstLeafId(first),
      };
}

// ── Internal widgets ──────────────────────────────────────────────────────────

class _PaneWrapper extends StatelessWidget {
  final String paneId;
  final bool isFocused;
  final VoidCallback onFocus;
  final Widget child;

  const _PaneWrapper({
    required this.paneId,
    required this.isFocused,
    required this.onFocus,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => onFocus(),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isFocused ? TermexColors.primary : TermexColors.border,
            width: isFocused ? 1.5 : 1.0,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _SplitContainer extends StatefulWidget {
  final SplitAxis axis;
  final double ratio;
  final Widget first;
  final Widget second;
  final ValueChanged<double> onRatioChanged;

  const _SplitContainer({
    required this.axis,
    required this.ratio,
    required this.first,
    required this.second,
    required this.onRatioChanged,
  });

  @override
  State<_SplitContainer> createState() => _SplitContainerState();
}

class _SplitContainerState extends State<_SplitContainer> {
  static const _handleSize = 6.0;
  double? _dragRatio;

  @override
  Widget build(BuildContext context) {
    final ratio = _dragRatio ?? widget.ratio;
    final isHorizontal = widget.axis == SplitAxis.horizontal;

    return LayoutBuilder(builder: (context, constraints) {
      final total = isHorizontal ? constraints.maxWidth : constraints.maxHeight;
      final firstSize = total * ratio;
      final secondSize = total * (1 - ratio) - _handleSize;

      return Flex(
        direction: isHorizontal ? Axis.horizontal : Axis.vertical,
        children: [
          SizedBox(
            width: isHorizontal ? firstSize : constraints.maxWidth,
            height: isHorizontal ? constraints.maxHeight : firstSize,
            child: widget.first,
          ),
          _DragHandle(
            axis: widget.axis,
            onDelta: (delta) {
              final newRatio =
                  ((ratio * total + delta) / total).clamp(0.15, 0.85);
              setState(() => _dragRatio = newRatio);
            },
            onEnd: () {
              if (_dragRatio != null) {
                widget.onRatioChanged(_dragRatio!);
                setState(() => _dragRatio = null);
              }
            },
          ),
          SizedBox(
            width: isHorizontal ? secondSize : constraints.maxWidth,
            height: isHorizontal ? constraints.maxHeight : secondSize,
            child: widget.second,
          ),
        ],
      );
    });
  }
}

class _DragHandle extends StatelessWidget {
  final SplitAxis axis;
  final ValueChanged<double> onDelta;
  final VoidCallback onEnd;

  const _DragHandle({
    required this.axis,
    required this.onDelta,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isHorizontal = axis == SplitAxis.horizontal;
    return MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: isHorizontal
            ? (d) => onDelta(d.primaryDelta ?? 0)
            : null,
        onVerticalDragUpdate: !isHorizontal
            ? (d) => onDelta(d.primaryDelta ?? 0)
            : null,
        onHorizontalDragEnd: isHorizontal ? (_) => onEnd() : null,
        onVerticalDragEnd: !isHorizontal ? (_) => onEnd() : null,
        child: Container(
          width: isHorizontal ? 6 : double.infinity,
          height: isHorizontal ? double.infinity : 6,
          color: TermexColors.border,
        ),
      ),
    );
  }
}
