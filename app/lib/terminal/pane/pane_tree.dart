/// Pane split tree data model.
///
/// A pane layout is a binary tree: leaf nodes are terminal panes and internal
/// nodes are splits (horizontal or vertical). The tree is immutable — all
/// mutations return new tree instances.
library;

import 'package:flutter/painting.dart';

/// Direction of a split.
enum SplitAxis { horizontal, vertical }

/// A node in the pane tree.
sealed class PaneNode {
  const PaneNode();
}

/// A leaf node — a single terminal pane.
final class PaneLeaf extends PaneNode {
  final String paneId;

  const PaneLeaf(this.paneId);
}

/// An internal split node with two children.
final class PaneSplit extends PaneNode {
  final SplitAxis axis;
  final PaneNode first;
  final PaneNode second;

  /// Fraction of space given to [first] (0.0–1.0).
  final double ratio;

  const PaneSplit({
    required this.axis,
    required this.first,
    required this.second,
    this.ratio = 0.5,
  });

  PaneSplit copyWith({
    SplitAxis? axis,
    PaneNode? first,
    PaneNode? second,
    double? ratio,
  }) =>
      PaneSplit(
        axis: axis ?? this.axis,
        first: first ?? this.first,
        second: second ?? this.second,
        ratio: ratio ?? this.ratio,
      );
}

/// Immutable pane tree with helper methods for structural mutation.
class PaneTree {
  final PaneNode root;
  final String focusedPaneId;

  const PaneTree({required this.root, required this.focusedPaneId});

  // ── Queries ───────────────────────────────────────────────────────────────

  /// All leaf pane IDs in depth-first left-to-right order.
  List<String> get allPaneIds {
    final ids = <String>[];
    void collect(PaneNode node) {
      switch (node) {
        case PaneLeaf(:final paneId):
          ids.add(paneId);
        case PaneSplit(:final first, :final second):
          collect(first);
          collect(second);
      }
    }

    collect(root);
    return ids;
  }

  bool get hasSplit => root is PaneSplit;

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Splits the focused pane, inserting [newPaneId] as the new sibling.
  PaneTree splitFocused(String newPaneId, SplitAxis axis) {
    final newRoot = _splitNode(root, focusedPaneId, newPaneId, axis);
    return PaneTree(root: newRoot, focusedPaneId: newPaneId);
  }

  /// Removes [paneId] from the tree. The sibling takes the vacated space.
  PaneTree remove(String paneId) {
    if (root is PaneLeaf) return this; // can't remove the only pane
    final newRoot = _removeNode(root, paneId);
    if (newRoot == null) return this;
    final remaining = _firstLeafId(newRoot);
    return PaneTree(
      root: newRoot,
      focusedPaneId: paneId == focusedPaneId ? remaining : focusedPaneId,
    );
  }

  PaneTree withFocus(String paneId) {
    if (!allPaneIds.contains(paneId)) return this;
    return PaneTree(root: root, focusedPaneId: paneId);
  }

  /// Updates the ratio of the split containing [paneId].
  PaneTree updateRatio(String splitOwnerPaneId, double ratio) {
    final newRoot = _updateRatioNode(root, splitOwnerPaneId, ratio);
    return PaneTree(root: newRoot, focusedPaneId: focusedPaneId);
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  PaneNode _splitNode(
      PaneNode node, String targetId, String newId, SplitAxis axis) {
    switch (node) {
      case PaneLeaf(:final paneId):
        if (paneId != targetId) return node;
        return PaneSplit(
          axis: axis,
          first: PaneLeaf(paneId),
          second: PaneLeaf(newId),
          ratio: 0.5,
        );
      case PaneSplit(:final first, :final second):
        return (node as PaneSplit).copyWith(
          first: _splitNode(first, targetId, newId, axis),
          second: _splitNode(second, targetId, newId, axis),
        );
    }
  }

  PaneNode? _removeNode(PaneNode node, String targetId) {
    switch (node) {
      case PaneLeaf(:final paneId):
        return paneId == targetId ? null : node;
      case PaneSplit(:final first, :final second):
        final newFirst = _removeNode(first, targetId);
        final newSecond = _removeNode(second, targetId);
        if (newFirst == null) return newSecond;
        if (newSecond == null) return newFirst;
        return (node as PaneSplit).copyWith(first: newFirst, second: newSecond);
    }
  }

  PaneNode _updateRatioNode(PaneNode node, String ownerId, double ratio) {
    switch (node) {
      case PaneLeaf():
        return node;
      case PaneSplit(:final first, :final second):
        final split = node as PaneSplit;
        final hasOwner = _hasLeaf(first, ownerId) || _hasLeaf(second, ownerId);
        return split.copyWith(
          ratio: hasOwner ? ratio.clamp(0.15, 0.85) : split.ratio,
          first: _updateRatioNode(first, ownerId, ratio),
          second: _updateRatioNode(second, ownerId, ratio),
        );
    }
  }

  bool _hasLeaf(PaneNode node, String id) {
    return switch (node) {
      PaneLeaf(:final paneId) => paneId == id,
      PaneSplit(:final first, :final second) =>
        _hasLeaf(first, id) || _hasLeaf(second, id),
    };
  }

  String _firstLeafId(PaneNode node) {
    return switch (node) {
      PaneLeaf(:final paneId) => paneId,
      PaneSplit(:final first) => _firstLeafId(first),
    };
  }
}
