/// In-terminal recording control bar (v0.47 spec §5.1).
///
/// A compact row displayed in the terminal toolbar when a session is
/// connected.  Shows recording status and start/stop toggle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'state/recording_provider.dart';

class RecordingControls extends ConsumerWidget {
  final String sessionId;

  const RecordingControls({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingProvider);
    final notifier = ref.read(recordingProvider.notifier);
    final isRecording = state.isRecording;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isRecording
            ? TermexColors.danger.withOpacity(0.12)
            : Colors.transparent,
        border: isRecording
            ? Border.all(color: TermexColors.danger.withOpacity(0.4))
            : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRecording) ...[
            _RecordingDot(),
            const SizedBox(width: 4),
            const Text(
              'REC',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: TermexColors.danger),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: () async {
              if (isRecording) {
                await notifier.stopRecording();
              } else {
                await notifier.startRecording(sessionId);
              }
            },
            child: Icon(
              isRecording ? Icons.stop_circle_outlined : Icons.fiber_manual_record,
              size: 16,
              color: isRecording ? TermexColors.danger : TermexColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Blinking red dot shown during active recording.
class _RecordingDot extends StatefulWidget {
  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: TermexColors.danger,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
