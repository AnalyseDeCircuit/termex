import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/recording/state/recording_provider.dart';

void main() {
  group('RecordingStatus', () {
    test('idle by default', () {
      const s = RecordingStatus();
      expect(s.active, isFalse);
      expect(s.recordingId, isNull);
      expect(s.elapsed, Duration.zero);
    });

    // The badge reads elapsed on every tick; a null start must not throw.
    test('elapsed is zero when never started', () {
      expect(const RecordingStatus(active: true).elapsed, Duration.zero);
    });

    test('elapsed counts from startedAt', () {
      final s = RecordingStatus(
        active: true,
        recordingId: 'r1',
        startedAt: DateTime.now().subtract(const Duration(seconds: 90)),
      );
      expect(s.elapsed.inSeconds, greaterThanOrEqualTo(90));
      expect(s.elapsed.inSeconds, lessThan(95));
    });
  });
}
