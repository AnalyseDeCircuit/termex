/// Pane split controller — ChangeNotifier wrapper around [PaneTree].
///
/// The terminal tab view listens to this controller to rebuild the split
/// layout whenever panes are added, removed, resized, or focused.
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'pane_tree.dart';

export 'pane_tree.dart';

/// Manages a [PaneTree] and notifies listeners on structural changes.
class PaneController extends ChangeNotifier {
  PaneTree _tree;

  PaneController({String? initialPaneId})
      : _tree = PaneTree(
          root: PaneLeaf(initialPaneId ?? const Uuid().v4()),
          focusedPaneId: initialPaneId ?? const Uuid().v4(),
        );

  PaneTree get tree => _tree;
  String get focusedPaneId => _tree.focusedPaneId;
  List<String> get allPaneIds => _tree.allPaneIds;
  bool get hasSplit => _tree.hasSplit;
  int get paneCount => _tree.allPaneIds.length;

  // ── Structural changes ────────────────────────────────────────────────────

  /// Splits the focused pane horizontally (side by side).
  String splitHorizontal() => _split(SplitAxis.horizontal);

  /// Splits the focused pane vertically (top and bottom).
  String splitVertical() => _split(SplitAxis.vertical);

  String _split(SplitAxis axis) {
    final newId = const Uuid().v4();
    _tree = _tree.splitFocused(newId, axis);
    notifyListeners();
    return newId;
  }

  /// Removes [paneId] from the tree and collapses the split.
  void removePane(String paneId) {
    _tree = _tree.remove(paneId);
    notifyListeners();
  }

  // ── Focus ─────────────────────────────────────────────────────────────────

  void focusPane(String paneId) {
    if (_tree.focusedPaneId == paneId) return;
    _tree = _tree.withFocus(paneId);
    notifyListeners();
  }

  /// Move focus to the next pane in depth-first order.
  void focusNext() {
    final ids = _tree.allPaneIds;
    if (ids.length <= 1) return;
    final idx = ids.indexOf(_tree.focusedPaneId);
    _tree = _tree.withFocus(ids[(idx + 1) % ids.length]);
    notifyListeners();
  }

  /// Move focus to the previous pane in depth-first order.
  void focusPrevious() {
    final ids = _tree.allPaneIds;
    if (ids.length <= 1) return;
    final idx = ids.indexOf(_tree.focusedPaneId);
    _tree = _tree.withFocus(ids[(idx - 1 + ids.length) % ids.length]);
    notifyListeners();
  }

  // ── Resize ────────────────────────────────────────────────────────────────

  /// Update the divider ratio for the split containing [paneId].
  void updateRatio(String paneId, double ratio) {
    _tree = _tree.updateRatio(paneId, ratio);
    notifyListeners();
  }
}
