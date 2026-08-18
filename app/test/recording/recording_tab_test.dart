import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/tabs/state/tab_controller.dart';

void main() {
  group('openRecordingTab', () {
    test('creates a tab that identifies as playback', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final id = c.read(tabListProvider.notifier)
          .openRecordingTab('/tmp/a.cast', 'prod');

      final tab = c.read(tabListProvider).single;
      expect(tab.id, id);
      expect(tab.isRecording, isTrue);
      expect(tab.recordingPath, '/tmp/a.cast');
      expect(tab.title, 'prod');
      expect(c.read(activeTabIdProvider), id);
    });

    // Reopening from the list is a common way to restart a replay; stacking a
    // fresh tab each time would fill the strip with duplicates.
    test('reuses the tab already playing that file', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(tabListProvider.notifier);

      final first = n.openRecordingTab('/tmp/a.cast', 'prod');
      n.openLocalTab();
      final second = n.openRecordingTab('/tmp/a.cast', 'prod');

      expect(second, first);
      expect(c.read(tabListProvider).where((t) => t.isRecording).length, 1);
      expect(c.read(activeTabIdProvider), first, reason: 'should refocus it');
    });

    test('separate recordings get separate tabs', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(tabListProvider.notifier);

      n.openRecordingTab('/tmp/a.cast', 'a');
      n.openRecordingTab('/tmp/b.cast', 'b');

      expect(c.read(tabListProvider).length, 2);
    });

    // copyWith is used for status updates; dropping the path there would
    // silently turn a playback tab back into a live one.
    test('a status update keeps the tab a playback tab', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(tabListProvider.notifier);

      final id = n.openRecordingTab('/tmp/a.cast', 'prod');
      n.updateStatus(id, TabStatus.disconnected);

      expect(c.read(tabListProvider).single.isRecording, isTrue);
    });

    test('a live tab is not playback', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(tabListProvider.notifier).openLocalTab();
      expect(c.read(tabListProvider).single.isRecording, isFalse);
    });
  });
}
