/// Top-level terminal view widget.
///
/// Composes:
/// - The pane split view (terminal rendering)
/// - Error diagnose floating banner (triggered by OSC 133 exit_code != 0)
/// - NL2Cmd overlay (Shift+Space shortcut)
/// - AI autocomplete source wiring
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../design/tokens.dart';
import '../features/ai/features/diagnose_sheet.dart';
import '../features/ai/features/error_detector.dart';
import '../features/ai/features/nl2cmd_overlay.dart';
import 'features/autocomplete/autocomplete_engine.dart';
import 'features/command_tracker/command_tracker.dart';
import 'pane/pane_split_view.dart';

/// Hint data shown in the floating error-diagnose banner.
class _DiagnoseHint {
  final String command;
  final String output;
  final List<DetectedError> errors;
  const _DiagnoseHint({
    required this.command,
    required this.output,
    required this.errors,
  });
}

/// Top-level widget that wraps the terminal pane view and wires up:
/// - OSC 133 command tracking → error diagnose banner
/// - Shift+Space → NL2Cmd overlay
/// - AI autocomplete source
class TerminalView extends ConsumerStatefulWidget {
  const TerminalView({super.key});

  @override
  ConsumerState<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends ConsumerState<TerminalView> {
  _DiagnoseHint? _diagnoseHint;
  bool _nl2cmdOpen = false;

  /// Accumulated terminal output for the in-progress command.
  final StringBuffer _currentOutput = StringBuffer();

  /// AI-backed suggestion source — fed asynchronously after AI responses.
  final _aiSource = AiBackedSuggestionSource();
  late final AutocompleteEngine _engine;
  late final CommandTracker _tracker;

  @override
  void initState() {
    super.initState();
    _engine = AutocompleteEngine(sources: [BuiltinCommandSource()])
      ..registerAiSource(_aiSource);
    _tracker = CommandTracker(onCommand: _onCommandFinished);
  }

  @override
  void dispose() {
    _currentOutput.clear();
    super.dispose();
  }

  // ── OSC 133 callback: surface diagnose banner on failure ─────────────────

  void _onCommandFinished(CommandRecord record) {
    if (record.exitCode != null && record.exitCode != 0) {
      final output = _currentOutput.toString();
      _currentOutput.clear();
      final errors = ErrorDetector().scan(output.split('\n'));
      if (errors.isNotEmpty && mounted) {
        setState(() {
          _diagnoseHint = _DiagnoseHint(
            command: record.command,
            output: output,
            errors: errors,
          );
        });
        // Auto-dismiss after 8 s if the user doesn't interact.
        Future.delayed(const Duration(seconds: 8), () {
          if (mounted && _diagnoseHint != null) {
            setState(() => _diagnoseHint = null);
          }
        });
      }
    } else {
      _currentOutput.clear();
    }
  }

  // ── Write NL2Cmd output to the focused pane's SSH stdin ──────────────────

  /// Writes [cmd] to the stdin of the currently focused pane's session.
  ///
  /// Pane ids and session ids are identical (both v4 UUIDs from
  /// [PaneController]). The focused pane id is read from a Riverpod scope
  /// when available; if no active pane is registered yet the write is a
  /// no-op (typical during app warm-up before the first SSH tab opens).
  void _writeToActivePane(String cmd) {
    final paneId = _readActivePaneId();
    if (paneId == null) return;
    bridge
        .writeStdin(
          sessionId: paneId,
          data: Uint8List.fromList(cmd.codeUnits),
        )
        .catchError((_) {});
  }

  /// Resolves the active pane id, or null if the split view hasn't published
  /// one yet. Placeholder until [PaneController] is lifted to a provider
  /// (tracked in v0.52 pane-state unification).
  String? _readActivePaneId() => null;

  // ── Keyboard: Shift+Space → NL2Cmd overlay ───────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.space &&
        HardwareKeyboard.instance.isShiftPressed) {
      setState(() => _nl2cmdOpen = true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        children: [
          // Main pane content
          PaneSplitView(
            controller: PaneController(),
            paneBuilder: (ctx, paneId) => const SizedBox.expand(),
          ),

          // Error diagnose banner (floats above terminal, at bottom edge)
          if (_diagnoseHint != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ErrorDiagnoseBanner(
                hint: _diagnoseHint!,
                onDiagnose: () {
                  final hint = _diagnoseHint!;
                  setState(() => _diagnoseHint = null);
                  showDiagnoseSheet(
                    context,
                    errors: hint.errors,
                    terminalContext: hint.output,
                  );
                },
                onDismiss: () => setState(() => _diagnoseHint = null),
              ),
            ),

          // NL2Cmd overlay (floats at top of terminal)
          if (_nl2cmdOpen)
            Positioned(
              top: 8,
              left: 24,
              right: 24,
              child: Nl2CmdOverlay(
                onClose: () => setState(() => _nl2cmdOpen = false),
                onAccept: (cmd) {
                  setState(() => _nl2cmdOpen = false);
                  _writeToActivePane(cmd);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Error diagnose banner ────────────────────────────────────────────────────

class _ErrorDiagnoseBanner extends StatelessWidget {
  final _DiagnoseHint hint;
  final VoidCallback onDiagnose;
  final VoidCallback onDismiss;

  const _ErrorDiagnoseBanner({
    required this.hint,
    required this.onDiagnose,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(top: BorderSide(color: TermexColors.warning.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 16, color: TermexColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '💡 AI 可以帮助分析这个错误',
              style: TextStyle(fontSize: 12, color: TermexColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: onDiagnose,
            style: TextButton.styleFrom(foregroundColor: TermexColors.warning),
            child: const Text('分析错误', style: TextStyle(fontSize: 12)),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 14, color: TermexColors.textSecondary),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
