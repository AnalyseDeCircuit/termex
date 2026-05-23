/// Pure state machine for the voice-input widget.
///
/// Kept platform-free (no speech_to_text dep here) so the mobile
/// shell can drive it from whatever speech provider it has —
/// iOS Dictation, Android SpeechRecognizer, or test fakes.
library;

/// One frame of speech recognition output. `partial` chunks are
/// transient (they may change as the recognizer hears more); `final_`
/// chunks are committed (they're appended to the canonical transcript).
class SpeechFrame {
  final String text;
  final bool isFinal;
  const SpeechFrame({required this.text, required this.isFinal});
}

/// Immutable snapshot of the dictation session state.
class VoiceTranscriptState {
  /// Fully-committed transcript so far (joined `final_` chunks).
  final String committed;

  /// Most recent in-flight `partial` chunk (may be empty).
  final String partial;

  /// True between `start()` and `stop()` / EOF.
  final bool listening;

  /// Set when the recognizer reports an error; clears on `start()`.
  final String? error;

  const VoiceTranscriptState({
    this.committed = '',
    this.partial = '',
    this.listening = false,
    this.error,
  });

  /// What the user should see in the preview pane — committed plus
  /// the current partial in lighter color (renderer's job; this just
  /// gives the raw concatenation).
  String get displayText {
    if (partial.isEmpty) return committed;
    if (committed.isEmpty) return partial;
    return '$committed $partial';
  }

  /// True iff the user has anything worth submitting.
  bool get hasContent => committed.trim().isNotEmpty;

  VoiceTranscriptState copyWith({
    String? committed,
    String? partial,
    bool? listening,
    String? error,
    bool clearError = false,
  }) {
    return VoiceTranscriptState(
      committed: committed ?? this.committed,
      partial: partial ?? this.partial,
      listening: listening ?? this.listening,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Pure reducer over [VoiceTranscriptState]. All side effects (mic
/// permission, recognizer lifecycle) belong to the caller.
class VoiceTranscriptReducer {
  /// Mark the session as started — clears any prior error and
  /// resets the partial buffer so a fresh utterance doesn't blend
  /// with stale data.
  static VoiceTranscriptState start(VoiceTranscriptState s) =>
      s.copyWith(listening: true, partial: '', clearError: true);

  /// Mark the session stopped (user tapped mic or recognizer EOF'd).
  /// Commits any outstanding partial as final so a clean tap-to-stop
  /// doesn't lose half-spoken words.
  static VoiceTranscriptState stop(VoiceTranscriptState s) {
    final committed = s.partial.isNotEmpty
        ? _append(s.committed, s.partial)
        : s.committed;
    return s.copyWith(listening: false, partial: '', committed: committed);
  }

  /// Apply a recognizer frame.
  static VoiceTranscriptState onFrame(
      VoiceTranscriptState s, SpeechFrame frame) {
    if (frame.isFinal) {
      return s.copyWith(
        committed: _append(s.committed, frame.text),
        partial: '',
      );
    }
    return s.copyWith(partial: frame.text);
  }

  /// Apply a recognizer error.
  static VoiceTranscriptState onError(
          VoiceTranscriptState s, String message) =>
      s.copyWith(listening: false, error: message, partial: '');

  /// Clear everything — for the "switch to keyboard" reset path.
  static VoiceTranscriptState reset() => const VoiceTranscriptState();

  static String _append(String existing, String fragment) {
    final f = fragment.trim();
    if (f.isEmpty) return existing;
    if (existing.isEmpty) return f;
    return '$existing $f';
  }
}
