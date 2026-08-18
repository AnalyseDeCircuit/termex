import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/tabs/state/tab_controller.dart';
import 'package:termex_shared/features/recording/widgets/recording_player.dart';
import 'package:termex_shared/l10n/app_localizations.dart';

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

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

  group('RecordingPlayer sizing', () {
    // In a tab the player kept the height it was given for the modal it first
    // shipped in, leaving the rest of the pane blank below the controls.
    testWidgets('fills its host when no height is given', (tester) async {
      // The test surface is 800x600, so a player that fills its pane measures
      // 600. The fixed 460 it used to carry would fail this.
      await tester.pumpWidget(
          _host(const RecordingPlayer(filePath: '/nope.cast')));
      await tester.pump();

      expect(tester.getSize(find.byType(RecordingPlayer)).height, 600,
          reason: 'player kept a fixed height instead of filling the pane');
    });

    testWidgets('honours an explicit height for dialog hosts', (tester) async {
      await tester.pumpWidget(_host(
        const Column(
          children: [RecordingPlayer(filePath: '/nope.cast', height: 460)],
        ),
      ));
      await tester.pump();

      expect(tester.getSize(find.byType(RecordingPlayer)).height, 460);
    });

    // A replay was seen painting a row of output over the tab strip above the
    // pane. Whatever the player renders has to stay inside its own box.
    testWidgets('clips its content to its own box', (tester) async {
      await tester.pumpWidget(
          _host(const RecordingPlayer(filePath: '/nope.cast')));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(RecordingPlayer),
          matching: find.byType(ClipRect),
        ),
        findsWidgets,
      );
    });
  });
}
