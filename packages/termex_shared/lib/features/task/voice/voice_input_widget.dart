/// Voice-first input panel for the v0.72.2 task assignment flow.
///
/// Renders the mic-toggle CTA + streaming transcript preview + a
/// "use keyboard instead" escape hatch. Speech recognition itself
/// is injected via `controller` so termex_shared stays free of any
/// platform-specific plugin dep (the mobile shell wires it to
/// `speech_to_text`).
library;

import 'package:flutter/widgets.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import 'voice_transcript_state.dart';

/// Interface the widget calls into for speech recognition.
abstract class VoiceController {
  Future<bool> initialize();
  Future<void> start({
    required void Function(SpeechFrame) onFrame,
    required void Function(String) onError,
    required VoidCallback onStatus,
  });
  Future<void> stop();
}

class VoiceInputWidget extends StatefulWidget {
  final VoiceController controller;
  final ValueChanged<String> onTranscriptChanged;
  final VoidCallback onSwitchToKeyboard;

  const VoiceInputWidget({
    super.key,
    required this.controller,
    required this.onTranscriptChanged,
    required this.onSwitchToKeyboard,
  });

  @override
  State<VoiceInputWidget> createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends State<VoiceInputWidget> {
  VoiceTranscriptState _state = const VoiceTranscriptState();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final ok = await widget.controller.initialize();
    if (mounted) {
      setState(() => _initialized = ok);
    }
  }

  Future<void> _toggle() async {
    if (!_initialized) return;
    if (_state.listening) {
      await widget.controller.stop();
      setState(() => _state = VoiceTranscriptReducer.stop(_state));
      widget.onTranscriptChanged(_state.committed);
    } else {
      setState(() => _state = VoiceTranscriptReducer.start(_state));
      await widget.controller.start(
        onFrame: (f) {
          if (!mounted) return;
          setState(() => _state = VoiceTranscriptReducer.onFrame(_state, f));
          if (f.isFinal) {
            widget.onTranscriptChanged(_state.committed);
          }
        },
        onError: (m) {
          if (!mounted) return;
          setState(() => _state = VoiceTranscriptReducer.onError(_state, m));
        },
        onStatus: () {},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MicButton(
          listening: _state.listening,
          enabled: _initialized,
          onTap: _toggle,
        ),
        const SizedBox(height: TermexSpacing.sm),
        Text(
          !_initialized
              ? 'Microphone unavailable'
              : _state.listening
                  ? 'Listening… tap to stop'
                  : 'Tap to speak',
          style: TermexTypography.body.copyWith(
            color: TermexColors.textSecondary,
          ),
        ),
        const SizedBox(height: TermexSpacing.md),
        _TranscriptPreview(state: _state),
        if (_state.error != null) ...[
          const SizedBox(height: TermexSpacing.xs),
          Text(
            _state.error!,
            style: TermexTypography.caption.copyWith(
              color: TermexColors.danger,
            ),
          ),
        ],
        const SizedBox(height: TermexSpacing.sm),
        GestureDetector(
          onTap: widget.onSwitchToKeyboard,
          child: Padding(
            padding: const EdgeInsets.all(TermexSpacing.xs),
            child: Text(
              'Use keyboard instead',
              style: TermexTypography.caption.copyWith(
                color: TermexColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool listening;
  final bool enabled;
  final VoidCallback onTap;

  const _MicButton({
    required this.listening,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? TermexColors.textMuted
        : (listening ? TermexColors.primary : TermexColors.backgroundTertiary);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: listening
              ? [
                  BoxShadow(
                    color: TermexColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ]
              : null,
          border: Border.all(
            color: listening ? TermexColors.primary : TermexColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          listening ? '●' : '🎤',
          style: TextStyle(
            fontSize: 44,
            color: enabled ? TermexColors.textPrimary : TermexColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _TranscriptPreview extends StatelessWidget {
  final VoiceTranscriptState state;
  const _TranscriptPreview({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.all(TermexSpacing.sm),
      decoration: BoxDecoration(
        color: TermexColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TermexColors.border),
      ),
      child: RichText(
        text: TextSpan(
          style: TermexTypography.body.copyWith(
            color: TermexColors.textPrimary,
          ),
          children: [
            if (state.committed.isNotEmpty)
              TextSpan(text: state.committed),
            if (state.committed.isNotEmpty && state.partial.isNotEmpty)
              const TextSpan(text: ' '),
            if (state.partial.isNotEmpty)
              TextSpan(
                text: state.partial,
                style: const TextStyle(
                  color: TermexColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (state.committed.isEmpty && state.partial.isEmpty)
              const TextSpan(
                text: 'Your speech will appear here',
                style: TextStyle(
                  color: TermexColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
