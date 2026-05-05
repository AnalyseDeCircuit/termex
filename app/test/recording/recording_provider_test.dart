import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:termex/features/recording/state/recording_provider.dart';

ProviderContainer _container() => ProviderContainer();

void main() {
  group('RecordingNotifier', () {
    test('initial state is empty', () {
      final c = _container();
      addTearDown(c.dispose);
      final s = c.read(recordingProvider);
      expect(s.recordings, isEmpty);
      expect(s.isRecording, isFalse);
      expect(s.isLoading, isFalse);
      expect(s.activeRecordingId, isNull);
    });

    test('loadRecordings sets isLoading then returns empty list', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(recordingProvider.notifier).loadRecordings();
      final s = c.read(recordingProvider);
      expect(s.isLoading, isFalse);
      expect(s.recordings, isEmpty);
    });

    test('startRecording sets activeRecordingId', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(recordingProvider.notifier).startRecording('sess-1');
      expect(c.read(recordingProvider).isRecording, isTrue);
      expect(c.read(recordingProvider).activeRecordingId, isNotNull);
    });

    test('startRecording is no-op when already recording', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(recordingProvider.notifier).startRecording('sess-1');
      final id1 = c.read(recordingProvider).activeRecordingId;
      await c.read(recordingProvider.notifier).startRecording('sess-1');
      final id2 = c.read(recordingProvider).activeRecordingId;
      expect(id1, equals(id2));
    });

    test('stopRecording clears activeRecordingId and adds to list', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(recordingProvider.notifier).startRecording('sess-1');
      await c.read(recordingProvider.notifier).stopRecording();
      final s = c.read(recordingProvider);
      expect(s.isRecording, isFalse);
      expect(s.recordings.length, equals(1));
    });

    test('deleteRecording removes entry from list', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(recordingProvider.notifier).startRecording('sess-1');
      await c.read(recordingProvider.notifier).stopRecording();
      final id = c.read(recordingProvider).recordings.first.id;
      await c.read(recordingProvider.notifier).deleteRecording(id);
      expect(c.read(recordingProvider).recordings, isEmpty);
    });

    test('exportRecording clears error', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(recordingProvider.notifier).exportRecording('id', '/tmp/x.cast');
      expect(c.read(recordingProvider).error, isNull);
    });

    test('RecordingEntry.durationLabel formats correctly', () {
      const e = RecordingEntry(
        id: 'x',
        sessionId: 's',
        filePath: '/tmp/x.cast',
        durationSeconds: 75,
        sizeBytes: 2048,
        createdAt: '2024-01-01T00:00:00Z',
      );
      expect(e.durationLabel, equals('01:15'));
    });

    test('RecordingEntry.sizeLabel shows MB for large files', () {
      const e = RecordingEntry(
        id: 'x',
        sessionId: 's',
        filePath: '/tmp/x.cast',
        durationSeconds: 0,
        sizeBytes: 2 * 1024 * 1024,
        createdAt: '2024-01-01T00:00:00Z',
      );
      expect(e.sizeLabel, contains('MB'));
    });
  });
}
