/// Asciicast v2 recording playback player (v0.47 spec §5.2).
///
/// Provides a self-contained UI widget for playing back a recorded session:
/// play/pause, seek scrubber, speed control (0.5× / 1× / 2× / 5×), and a
/// read-only terminal output area showing the current frame.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'asciicast_parser.dart';
import 'state/recording_provider.dart';

// ─── Playback state ──────────────────────────────────────────────────────────

class PlaybackState {
  final AsciicastFile? file;
  final bool isPlaying;
  final double position;   // seconds
  final double speed;      // 0.5 / 1.0 / 2.0 / 5.0
  final String frameText;  // concatenated output up to [position]

  const PlaybackState({
    this.file,
    this.isPlaying = false,
    this.position = 0.0,
    this.speed = 1.0,
    this.frameText = '',
  });

  double get duration => file?.duration ?? 0.0;

  double get progress => duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;

  PlaybackState copyWith({
    AsciicastFile? file,
    bool? isPlaying,
    double? position,
    double? speed,
    String? frameText,
  }) =>
      PlaybackState(
        file: file ?? this.file,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        speed: speed ?? this.speed,
        frameText: frameText ?? this.frameText,
      );
}

// ─── Controller ──────────────────────────────────────────────────────────────

class PlaybackController {
  PlaybackController._();
  static final PlaybackController instance = PlaybackController._();

  PlaybackState _state = const PlaybackState();
  final _listeners = <void Function(PlaybackState)>[];

  Timer? _ticker;

  PlaybackState get state => _state;

  void addListener(void Function(PlaybackState) l) => _listeners.add(l);
  void removeListener(void Function(PlaybackState) l) => _listeners.remove(l);
  void _notify() {
    for (final l in _listeners) l(_state);
  }

  void load(AsciicastFile file) {
    _stop();
    _state = PlaybackState(file: file);
    _notify();
  }

  void play() {
    if (_state.file == null || _state.isPlaying) return;
    if (_state.position >= _state.duration) seek(0);
    _state = _state.copyWith(isPlaying: true);
    _notify();
    _startTicker();
  }

  void pause() {
    _stop();
    _state = _state.copyWith(isPlaying: false);
    _notify();
  }

  void togglePlay() => _state.isPlaying ? pause() : play();

  void seek(double seconds) {
    final pos = seconds.clamp(0.0, _state.duration);
    _state = _state.copyWith(position: pos, frameText: _buildFrame(pos));
    _notify();
  }

  void setSpeed(double speed) {
    _state = _state.copyWith(speed: speed);
    _notify();
  }

  void _startTicker() {
    _ticker?.cancel();
    const tickMs = 50;
    _ticker = Timer.periodic(const Duration(milliseconds: tickMs), (_) {
      if (!_state.isPlaying) {
        _ticker?.cancel();
        return;
      }
      final inc = tickMs / 1000.0 * _state.speed;
      final next = _state.position + inc;
      if (next >= _state.duration) {
        _state = _state.copyWith(
          position: _state.duration,
          isPlaying: false,
          frameText: _buildFrame(_state.duration),
        );
        _ticker?.cancel();
      } else {
        _state = _state.copyWith(
          position: next,
          frameText: _buildFrame(next),
        );
      }
      _notify();
    });
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  String _buildFrame(double atSeconds) {
    final file = _state.file;
    if (file == null) return '';
    return file.visibleAt(atSeconds).map((e) => e.data).join();
  }

  void dispose() {
    _stop();
    _listeners.clear();
  }
}

// ─── Widget ───────────────────────────────────────────────────────────────────

class RecordingPlayer extends ConsumerStatefulWidget {
  final RecordingEntry entry;

  const RecordingPlayer({super.key, required this.entry});

  @override
  ConsumerState<RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends ConsumerState<RecordingPlayer> {
  final _ctrl = PlaybackController.instance;
  PlaybackState _playback = const PlaybackState();

  static const _speeds = [0.5, 1.0, 2.0, 5.0];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onPlayback);
    _loadFile();
  }

  void _loadFile() {
    // In production, read the file via FRB/local_fs.
    // For now load a stub empty file to show the player UI.
    final stub = AsciicastFile(
      header: AsciicastHeader(
        width: 80,
        height: 24,
        duration: widget.entry.durationSeconds.toDouble(),
        title: widget.entry.displayTitle,
      ),
      events: const [],
    );
    _ctrl.load(stub);
  }

  void _onPlayback(PlaybackState s) {
    if (mounted) setState(() => _playback = s);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onPlayback);
    _ctrl.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TermexColors.backgroundPrimary,
      child: Column(
        children: [
          _PlayerHeader(entry: widget.entry),
          Expanded(child: _TerminalOutput(text: _playback.frameText)),
          _PlayerControls(playback: _playback, ctrl: _ctrl, speeds: _speeds),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _PlayerHeader extends StatelessWidget {
  final RecordingEntry entry;
  const _PlayerHeader({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline,
              size: 16, color: TermexColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.displayTitle,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: TermexColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(entry.durationLabel,
              style: const TextStyle(
                  fontSize: 11, color: TermexColors.textSecondary)),
        ],
      ),
    );
  }
}

class _TerminalOutput extends StatelessWidget {
  final String text;
  const _TerminalOutput({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E2E),
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        reverse: true,
        child: Text(
          text.isEmpty ? '…' : text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFFCDD6F4),
          ),
        ),
      ),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  final PlaybackState playback;
  final PlaybackController ctrl;
  final List<double> speeds;

  const _PlayerControls(
      {required this.playback, required this.ctrl, required this.speeds});

  @override
  Widget build(BuildContext context) {
    final dur = playback.duration;
    final pos = playback.position;
    final label =
        '${_fmt(pos)} / ${_fmt(dur)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(top: BorderSide(color: TermexColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: playback.progress,
            onChanged: (v) => ctrl.seek(v * dur),
            activeColor: TermexColors.primary,
            inactiveColor: TermexColors.border,
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                    playback.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 20,
                    color: TermexColors.primary),
                onPressed: ctrl.togglePlay,
                tooltip: playback.isPlaying ? '暂停' : '播放',
              ),
              IconButton(
                icon: const Icon(Icons.replay, size: 18),
                onPressed: () => ctrl.seek(0),
                tooltip: '重播',
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: TermexColors.textSecondary,
                      fontFamily: 'monospace')),
              const Spacer(),
              // Speed selector
              ...speeds.map((s) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _SpeedChip(
                      speed: s,
                      selected: playback.speed == s,
                      onTap: () => ctrl.setSpeed(s),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(double s) {
    final m = s ~/ 60;
    final sec = (s % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

class _SpeedChip extends StatelessWidget {
  final double speed;
  final bool selected;
  final VoidCallback onTap;

  const _SpeedChip(
      {required this.speed, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = speed == 0.5
        ? '0.5×'
        : speed == 1.0
            ? '1×'
            : speed == 2.0
                ? '2×'
                : '5×';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? TermexColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: selected ? TermexColors.primary : TermexColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: selected ? Colors.white : TermexColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
