/// OSC 133 shell-integration command tracker.
///
/// Many modern shells (bash with `PROMPT_COMMAND`, zsh with `precmd` /
/// `preexec`, fish natively) emit OSC 133 sequences to mark command
/// boundaries and carry exit codes.
///
/// Sequence grammar:
///   ESC ] 133 ; A ST   — prompt start
///   ESC ] 133 ; B ST   — command start (user is typing)
///   ESC ] 133 ; C ST   — command executed (output begins)
///   ESC ] 133 ; D [; <code>] ST — command finished with exit code
///
/// [CommandTracker] parses these sequences from the raw terminal byte stream
/// and emits [CommandRecord] events via [onCommand].
library;

/// A single completed shell command with timing and exit-code information.
class CommandRecord {
  final String command;
  final DateTime startAt;
  final DateTime endAt;
  final int? exitCode;

  CommandRecord({
    required this.command,
    required this.startAt,
    required this.endAt,
    this.exitCode,
  });

  Duration get duration => endAt.difference(startAt);
  bool get succeeded => exitCode == 0;
}

/// Parses OSC 133 shell-integration sequences from a raw byte stream.
///
/// Typical usage:
/// ```dart
/// final tracker = CommandTracker(onCommand: (r) => print(r.command));
/// tracker.feed(bytes); // called for each chunk from the SSH stdout stream
/// ```
class CommandTracker {
  final void Function(CommandRecord record) onCommand;

  CommandTracker({required this.onCommand});

  // ── Internal state ────────────────────────────────────────────────────────

  // OSC terminator: either BEL (0x07) or ST (ESC \  = 0x1B 0x5C).
  static const int _esc = 0x1B;
  static const int _bel = 0x07;

  final StringBuffer _pending = StringBuffer();
  bool _inOsc = false;
  final StringBuffer _oscBuf = StringBuffer();

  // Phase-tracking: what state the prompt FSM is in.
  String? _currentCommand;
  DateTime? _commandStart;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Feed a raw byte chunk from the terminal stream.
  void feed(List<int> bytes) {
    for (int i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      if (_inOsc) {
        if (b == _bel) {
          _handleOsc(_oscBuf.toString());
          _oscBuf.clear();
          _inOsc = false;
        } else if (b == _esc && i + 1 < bytes.length && bytes[i + 1] == 0x5C) {
          // ST = ESC \
          _handleOsc(_oscBuf.toString());
          _oscBuf.clear();
          _inOsc = false;
          i++; // skip the backslash
        } else {
          _oscBuf.writeCharCode(b);
        }
      } else if (b == _esc && i + 1 < bytes.length && bytes[i + 1] == 0x5D) {
        // Start of OSC: ESC ]
        _inOsc = true;
        i++; // skip ]
      } else {
        // Regular terminal data — accumulate for command text parsing.
        _pending.writeCharCode(b);
      }
    }
  }

  /// Resets internal state (e.g. on disconnect).
  void reset() {
    _pending.clear();
    _oscBuf.clear();
    _inOsc = false;
    _currentCommand = null;
    _commandStart = null;
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _handleOsc(String osc) {
    // Only care about OSC 133 sequences.
    if (!osc.startsWith('133;')) return;
    final payload = osc.substring(4);

    switch (payload[0]) {
      case 'A':
        // Prompt start — user is about to see the prompt.
        break;

      case 'B':
        // Command start — user begins typing; clear the pending buffer.
        _pending.clear();
        _commandStart = DateTime.now();
        break;

      case 'C':
        // Command executed — capture what the user typed as the command text.
        _currentCommand = _pending.toString().trim();
        _pending.clear();
        break;

      case 'D':
        // Command finished.
        final now = DateTime.now();
        int? exitCode;
        if (payload.length > 2 && payload[1] == ';') {
          exitCode = int.tryParse(payload.substring(2));
        }
        if (_currentCommand != null && _commandStart != null) {
          onCommand(CommandRecord(
            command: _currentCommand!,
            startAt: _commandStart!,
            endAt: now,
            exitCode: exitCode,
          ));
        }
        _currentCommand = null;
        _commandStart = null;
        _pending.clear();
        break;
    }
  }
}
