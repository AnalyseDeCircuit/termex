import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/task/voice/voice_transcript_state.dart';

void main() {
  group('VoiceTranscriptReducer', () {
    test('start clears partial + error, sets listening', () {
      final s0 = const VoiceTranscriptState(
        committed: 'hi',
        partial: 'th',
        error: 'old',
      );
      final s1 = VoiceTranscriptReducer.start(s0);
      expect(s1.listening, isTrue);
      expect(s1.partial, '');
      expect(s1.error, isNull);
      expect(s1.committed, 'hi'); // committed survives
    });

    test('onFrame partial just updates partial', () {
      final s = VoiceTranscriptReducer.onFrame(
        const VoiceTranscriptState(committed: 'hello'),
        const SpeechFrame(text: 'wor', isFinal: false),
      );
      expect(s.partial, 'wor');
      expect(s.committed, 'hello');
    });

    test('onFrame final commits and clears partial', () {
      final s = VoiceTranscriptReducer.onFrame(
        const VoiceTranscriptState(committed: 'hello', partial: 'wor'),
        const SpeechFrame(text: 'world', isFinal: true),
      );
      expect(s.committed, 'hello world');
      expect(s.partial, '');
    });

    test('onFrame final from empty committed initializes', () {
      final s = VoiceTranscriptReducer.onFrame(
        const VoiceTranscriptState(),
        const SpeechFrame(text: 'first', isFinal: true),
      );
      expect(s.committed, 'first');
    });

    test('stop promotes outstanding partial to committed', () {
      final s = VoiceTranscriptReducer.stop(
        const VoiceTranscriptState(
            committed: 'hello', partial: 'world', listening: true),
      );
      expect(s.listening, isFalse);
      expect(s.committed, 'hello world');
      expect(s.partial, '');
    });

    test('stop with empty partial keeps committed unchanged', () {
      final s = VoiceTranscriptReducer.stop(
        const VoiceTranscriptState(committed: 'hello', listening: true),
      );
      expect(s.committed, 'hello');
    });

    test('onError clears partial + sets error message', () {
      final s = VoiceTranscriptReducer.onError(
        const VoiceTranscriptState(partial: 'foo', listening: true),
        'network down',
      );
      expect(s.listening, isFalse);
      expect(s.error, 'network down');
      expect(s.partial, '');
    });

    test('reset returns empty state', () {
      final s = VoiceTranscriptReducer.reset();
      expect(s.committed, isEmpty);
      expect(s.partial, isEmpty);
      expect(s.listening, isFalse);
      expect(s.error, isNull);
    });
  });

  group('VoiceTranscriptState', () {
    test('displayText joins committed + partial with space', () {
      const s = VoiceTranscriptState(committed: 'hello', partial: 'wo');
      expect(s.displayText, 'hello wo');
    });

    test('displayText drops join when one side empty', () {
      expect(const VoiceTranscriptState(committed: 'hi').displayText, 'hi');
      expect(const VoiceTranscriptState(partial: 'th').displayText, 'th');
      expect(const VoiceTranscriptState().displayText, '');
    });

    test('hasContent ignores whitespace-only committed', () {
      expect(const VoiceTranscriptState(committed: '   ').hasContent, isFalse);
      expect(const VoiceTranscriptState(committed: 'hi').hasContent, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      const s = VoiceTranscriptState(committed: 'a', partial: 'b');
      final s2 = s.copyWith(listening: true);
      expect(s2.committed, 'a');
      expect(s2.partial, 'b');
      expect(s2.listening, isTrue);
    });

    test('copyWith clearError resets error', () {
      const s = VoiceTranscriptState(error: 'x');
      final s2 = s.copyWith(clearError: true);
      expect(s2.error, isNull);
    });
  });
}
