/// Playback for a recorded session.
///
/// Port of `src/components/recording/RecordingPlayer.vue`: replays the
/// asciicast into a read-only terminal with play/pause, speed and seek.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:termex_bridge/src/api.dart' as bridge;
import 'package:xterm/xterm.dart' as xt;

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/dialog.dart';
import '../asciicast.dart';

/// Opens [filePath] in a playback dialog.
Future<void> showRecordingPlayer(
  BuildContext context, {
  required String filePath,
  required String title,
}) {
  return showTermexDialog<void>(
    context: context,
    title: title,
    size: DialogSize.large,
    body: RecordingPlayer(filePath: filePath),
  );
}

class RecordingPlayer extends StatefulWidget {
  final String filePath;
  const RecordingPlayer({super.key, required this.filePath});

  @override
  State<RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<RecordingPlayer> {
  final _terminal = xt.Terminal(maxLines: 10000);

  Cast? _cast;
  String? _error;
  bool _loading = true;

  /// Index of the next event to emit.
  int _cursor = 0;
  Duration _position = Duration.zero;
  bool _playing = false;
  double _speed = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final content = await bridge.recordingRead(path: widget.filePath);
      final cast = Cast.parse(content);
      if (!mounted) return;
      setState(() {
        _cast = cast;
        _loading = false;
      });
      if (cast.events.isEmpty) return;
      _play();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Advances playback by wall-clock time, emitting everything now due.
  ///
  /// Driven by a fixed tick rather than one timer per event: recordings can
  /// hold tens of thousands of events, and scheduling each one separately
  /// makes seeking and speed changes impossible to cancel cleanly.
  void _tick() {
    final cast = _cast;
    if (cast == null) return;

    const step = Duration(milliseconds: 50);
    final next = _position + step * _speed;
    final buffer = StringBuffer();

    while (_cursor < cast.events.length &&
        cast.events[_cursor].time * 1000 <= next.inMilliseconds) {
      buffer.write(cast.events[_cursor].data);
      _cursor++;
    }
    if (buffer.isNotEmpty) _terminal.write(buffer.toString());

    setState(() => _position = next);

    if (_cursor >= cast.events.length) _pause();
  }

  void _play() {
    final cast = _cast;
    if (cast == null || cast.events.isEmpty) return;
    // Replaying from the end would emit nothing; rewind first.
    if (_cursor >= cast.events.length) _seek(Duration.zero);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
    setState(() => _playing = true);
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _playing = false);
  }

  /// Jumps to [to] by replaying from the start.
  ///
  /// A terminal's state is the sum of everything written to it, so there is
  /// no way to scrub backwards other than rebuilding the screen from zero.
  void _seek(Duration to) {
    final cast = _cast;
    if (cast == null) return;

    _terminal.write('\x1b[2J\x1b[H');
    final buffer = StringBuffer();
    _cursor = 0;
    while (_cursor < cast.events.length &&
        cast.events[_cursor].time * 1000 <= to.inMilliseconds) {
      buffer.write(cast.events[_cursor].data);
      _cursor++;
    }
    if (buffer.isNotEmpty) _terminal.write(buffer.toString());
    setState(() => _position = to);
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const SizedBox(
        height: 420,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 420,
        child: Center(
          child: Text(_error!,
              style: TextStyle(color: context.colors.danger, fontSize: 12)),
        ),
      );
    }

    final cast = _cast!;
    if (cast.events.isEmpty) {
      return SizedBox(
        height: 420,
        child: Center(
          child: Text(l10n.recordingEmptyCast,
              style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
        ),
      );
    }

    final total = cast.duration;
    return SizedBox(
      height: 460,
      child: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: context.colors.backgroundPrimary,
              child: xt.TerminalView(_terminal, autofocus: false, readOnly: true),
            ),
          ),
          const SizedBox(height: TermexSpacing.sm),
          Row(
            children: [
              IconButton(
                iconSize: 18,
                icon: Icon(_playing ? Icons.pause : Icons.play_arrow,
                    color: context.colors.textPrimary),
                tooltip: _playing ? l10n.recordingPause : l10n.recordingPlay,
                onPressed: _playing ? _pause : _play,
              ),
              Text(_fmt(_position),
                  style: TextStyle(
                      fontSize: 11, color: context.colors.textMuted)),
              Expanded(
                child: Slider(
                  value: _position.inMilliseconds
                      .clamp(0, total.inMilliseconds)
                      .toDouble(),
                  max: total.inMilliseconds.toDouble().clamp(1, double.infinity),
                  onChanged: (v) =>
                      _seek(Duration(milliseconds: v.round())),
                ),
              ),
              Text(_fmt(total),
                  style: TextStyle(
                      fontSize: 11, color: context.colors.textMuted)),
              const SizedBox(width: TermexSpacing.sm),
              DropdownButton<double>(
                value: _speed,
                underline: const SizedBox.shrink(),
                style: TextStyle(
                    fontSize: 11, color: context.colors.textSecondary),
                items: const [0.5, 1, 2, 4]
                    .map((s) => DropdownMenuItem(
                        value: s.toDouble(), child: Text('${s}x')))
                    .toList(),
                onChanged: (v) => setState(() => _speed = v ?? 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
