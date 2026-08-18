/// Start/stop control for session recording, shown in the terminal chrome.
///
/// Port of `src/components/recording/RecordingControls.vue`: a dot-only
/// button while idle, and a blinking REC badge with elapsed time while
/// recording, which doubles as the stop button.
library;

import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart' show BufferRangeLine, CellOffset;

import '../../../terminal/pane/terminal_pane.dart'
    show terminalInstanceProvider;

import '../../../design/colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/clickable.dart';
import '../state/recording_provider.dart';

class RecordingControls extends ConsumerStatefulWidget {
  final String sessionId;
  final String serverId;
  final String serverName;

  /// Terminal geometry, written into the asciicast header so a player can
  /// reproduce the original layout.
  final int cols;
  final int rows;

  const RecordingControls({
    super.key,
    required this.sessionId,
    required this.serverId,
    required this.serverName,
    this.cols = 80,
    this.rows = 24,
  });

  @override
  ConsumerState<RecordingControls> createState() => _RecordingControlsState();
}

class _RecordingControlsState extends ConsumerState<RecordingControls> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // A recording can outlive this widget — reopening the tab must show REC
    // rather than an idle button.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(recordingProvider(widget.sessionId).notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Drives the elapsed-time readout. Started on demand so an idle session
  /// costs no timer.
  void _syncTicker(bool active) {
    if (active && _ticker == null) {
      _ticker =
          Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    } else if (!active && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  /// The terminal's visible contents, as the recording's opening frame.
  ///
  /// Only the viewport, not the scrollback: a replay reproduces a screen, and
  /// prepending thousands of scrolled-off lines would push the actual starting
  /// state out of view. Cleared and homed first so the frame lands on a known
  /// canvas.
  String? _currentScreen() {
    try {
      final term = ref.read(terminalInstanceProvider(widget.sessionId));
      final buffer = term.buffer;
      final height = term.viewHeight;
      final first = (buffer.height - height).clamp(0, buffer.height);
      final text = buffer
          .getText(BufferRangeLine(
            CellOffset(0, first),
            CellOffset(term.viewWidth - 1, buffer.height - 1),
          ))
          .trimRight();
      if (text.isEmpty) return null;
      // CRLF: the recording replays into a terminal, where a bare \n moves
      // down without returning to column 0.
      return '\x1b[2J\x1b[H${text.replaceAll('\n', '\r\n')}\r\n';
    } catch (_) {
      // No terminal for this session (tests, a pane that never mounted) —
      // recording without an opening frame is still correct, just blank.
      return null;
    }
  }

  static String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(recordingProvider(widget.sessionId));
    final notifier = ref.read(recordingProvider(widget.sessionId).notifier);

    // Scheduled out of build: _syncTicker calls setState when it fires.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTicker(status.active);
    });

    if (!status.active) {
      return _Btn(
        tooltip: l10n.recordingStartRecording,
        onTap: () => notifier.start(
          serverId: widget.serverId,
          serverName: widget.serverName,
          cols: widget.cols,
          rows: widget.rows,
          title: widget.serverName,
          initialScreen: _currentScreen(),
        ),
        child: _Dot(color: context.colors.textMuted, size: 8),
      );
    }

    return _Btn(
      tooltip: l10n.recordingStopRecording,
      onTap: notifier.stop,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BlinkingDot(),
          const SizedBox(width: 4),
          Text(
            'REC',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.colors.danger,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _format(status.elapsed),
            style: TextStyle(
              fontSize: 10,
              color: context.colors.textMuted,
              // Keeps the badge from jittering as the digits change.
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatefulWidget {
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  const _Btn({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Clickable(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered
                  ? context.colors.danger.withValues(alpha: 0.1)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(3),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// The pulsing dot that marks an in-progress recording.
class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.3).animate(_c),
        child: _Dot(color: context.colors.danger, size: 6),
      );
}
