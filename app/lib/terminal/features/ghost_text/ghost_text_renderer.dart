/// Ghost text overlay widget.
///
/// Renders the grey suggestion suffix after the cursor inside the terminal
/// view.  Placed by the terminal renderer at the cursor's pixel position.
///
/// Key handling is the responsibility of the parent [TerminalView] which owns
/// the [FocusNode]; this widget only handles the visual presentation.
library;

import 'package:flutter/widgets.dart';

import '../../../../design/colors.dart';
import '../../../../design/typography.dart';
import 'ghost_text_engine.dart';

export 'ghost_text_engine.dart' show GhostTextEngine, GhostTextSuggestion;

/// Overlay that shows ghost-text after the cursor.
///
/// Wrap the terminal area in a [Stack] and add this widget at the cursor
/// position.  It renders nothing when [suggestion] is `null`.
class GhostTextOverlay extends StatelessWidget {
  /// The current suggestion, or `null` to hide.
  final GhostTextSuggestion? suggestion;

  /// Font size matching the terminal cell font size.
  final double fontSize;

  /// Cell width in logical pixels (for correct horizontal placement).
  final double cellWidth;

  const GhostTextOverlay({
    super.key,
    required this.suggestion,
    this.fontSize = 13.0,
    this.cellWidth = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final sug = suggestion;
    if (sug == null || sug.ghostSuffix.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Text(
        sug.ghostSuffix,
        style: TermexTypography.monospace.copyWith(
          fontSize: fontSize,
          color: TermexColors.textMuted.withOpacity(0.55),
          // Do not inherit any selection or decoration from parent.
          decoration: TextDecoration.none,
        ),
        softWrap: false,
        overflow: TextOverflow.clip,
      ),
    );
  }
}

/// Controller that manages [GhostTextEngine] state and exposes a [ValueNotifier]
/// that the terminal view can watch to rebuild only when the suggestion changes.
class GhostTextController extends ChangeNotifier {
  final GhostTextEngine _engine;
  GhostTextSuggestion? _current;

  GhostTextController({GhostTextEngine? engine})
      : _engine = engine ?? GhostTextEngine();

  GhostTextSuggestion? get current => _current;

  /// Call whenever the terminal input line changes.
  void onInputChanged(String inputLine) {
    final next = _engine.suggest(inputLine);
    if (next?.fullCommand != _current?.fullCommand) {
      _current = next;
      notifyListeners();
    }
  }

  /// Dismiss the ghost text without modifying the input buffer (Esc key).
  void dismiss() {
    if (_current != null) {
      _current = null;
      notifyListeners();
    }
  }

  /// Returns the full suffix to append for a full-accept (Tab).
  String? acceptFull() {
    final s = _current?.ghostSuffix;
    _current = null;
    notifyListeners();
    return s;
  }

  /// Returns the one-word suffix to append (→ key).
  String? acceptOneWord(String currentInputLine) {
    final sug = _current;
    if (sug == null) return null;
    final word = GhostTextEngine.acceptOneWord(currentInputLine, sug.ghostSuffix);
    _current = null;
    notifyListeners();
    return word;
  }

  /// Record a completed command (called after OSC 133 D event).
  void recordCommand(String command) {
    _engine.recordCommand(command);
  }

  /// Seed with a list of existing history items (e.g. from DB on load).
  void seedHistory(List<String> commands) {
    _engine.recordAll(commands);
  }
}
