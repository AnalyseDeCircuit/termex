/// Tmux pane and window data model.
///
/// Represents the tmux session state as reported by the server via
/// `tmux list-windows -F` / `tmux list-panes -F` output.  This model is
/// Dart-only and has no FRB dependency — it is populated from parsed text.
library;

/// A single tmux pane within a window.
class TmuxPane {
  final String paneId; // %N
  final int windowIndex;
  final int paneIndex;
  final int width;
  final int height;
  final int top;
  final int left;
  final bool isActive;
  final String? currentCommand;

  const TmuxPane({
    required this.paneId,
    required this.windowIndex,
    required this.paneIndex,
    required this.width,
    required this.height,
    required this.top,
    required this.left,
    required this.isActive,
    this.currentCommand,
  });

  TmuxPane copyWith({bool? isActive, String? currentCommand}) => TmuxPane(
        paneId: paneId,
        windowIndex: windowIndex,
        paneIndex: paneIndex,
        width: width,
        height: height,
        top: top,
        left: left,
        isActive: isActive ?? this.isActive,
        currentCommand: currentCommand ?? this.currentCommand,
      );
}

/// A tmux window (tab) which may contain multiple panes.
class TmuxWindow {
  final int index;
  final String name;
  final bool isActive;
  final List<TmuxPane> panes;

  const TmuxWindow({
    required this.index,
    required this.name,
    required this.isActive,
    required this.panes,
  });

  TmuxWindow copyWith({
    String? name,
    bool? isActive,
    List<TmuxPane>? panes,
  }) =>
      TmuxWindow(
        index: index,
        name: name ?? this.name,
        isActive: isActive ?? this.isActive,
        panes: panes ?? this.panes,
      );

  TmuxPane? get activePane =>
      panes.where((p) => p.isActive).firstOrNull ?? panes.firstOrNull;
}

/// Parser for `tmux list-panes -a -F '...'` output.
class TmuxPaneParser {
  // Format: #S:#I.#P|#W|#{pane_active}|#{pane_width}|#{pane_height}|#{pane_top}|#{pane_left}|#{pane_current_command}
  static const _format =
      '#S:#I.#P|#W|#{pane_active}|#{pane_width}|#{pane_height}|#{pane_top}|#{pane_left}|#{pane_id}|#{pane_current_command}';

  static String get listPanesCommand =>
      "tmux list-panes -a -F '$_format'";

  /// Parse the raw stdout of the list-panes command into a window map.
  static Map<int, TmuxWindow> parse(String output) {
    final windows = <int, TmuxWindow>{};

    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split('|');
      if (parts.length < 9) continue;

      try {
        // parts[0]: "session:windowIdx.paneIdx"
        final sessionPart = parts[0];
        final colonIdx = sessionPart.indexOf(':');
        final dotIdx = sessionPart.indexOf('.');
        if (colonIdx == -1 || dotIdx == -1) continue;

        final windowIdx = int.parse(sessionPart.substring(colonIdx + 1, dotIdx));
        final paneIdx = int.parse(sessionPart.substring(dotIdx + 1));

        final windowName = parts[1];
        final isActive = parts[2] == '1';
        final width = int.tryParse(parts[3]) ?? 80;
        final height = int.tryParse(parts[4]) ?? 24;
        final top = int.tryParse(parts[5]) ?? 0;
        final left = int.tryParse(parts[6]) ?? 0;
        final paneId = parts[7];
        final currentCommand = parts[8].isEmpty ? null : parts[8];

        final pane = TmuxPane(
          paneId: paneId,
          windowIndex: windowIdx,
          paneIndex: paneIdx,
          width: width,
          height: height,
          top: top,
          left: left,
          isActive: isActive,
          currentCommand: currentCommand,
        );

        final window = windows[windowIdx];
        if (window == null) {
          windows[windowIdx] = TmuxWindow(
            index: windowIdx,
            name: windowName,
            isActive: false,
            panes: [pane],
          );
        } else {
          windows[windowIdx] = window.copyWith(
            panes: [...window.panes, pane],
          );
        }
      } catch (_) {
        continue;
      }
    }

    return windows;
  }
}
