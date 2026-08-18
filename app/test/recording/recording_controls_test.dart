import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/recording/state/recording_provider.dart';
import 'package:termex_shared/features/recording/widgets/recording_controls.dart';
import 'package:termex_shared/l10n/app_localizations.dart';

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('RecordingControls', () {
    // The control first shipped resolving its server identity by matching the
    // session id against TabEntry.id. Those are different identifiers — the
    // shell converts between them — so the lookup never hit and the widget
    // rendered as an empty box. Nothing failed; the button was simply absent.
    testWidgets('renders something visible when idle', (tester) async {
      await tester.pumpWidget(_host(const RecordingControls(
        sessionId: 's1',
        serverId: 'srv-1',
        serverName: 'prod',
      )));
      await tester.pump();

      final size = tester.getSize(find.byType(RecordingControls));
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    });

    testWidgets('exposes a start action to assistive tech', (tester) async {
      await tester.pumpWidget(_host(const RecordingControls(
        sessionId: 's2',
        serverId: 'srv-1',
        serverName: 'prod',
      )));
      await tester.pump();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(RecordingControls)));
      expect(find.bySemanticsLabel(l10n.recordingStartRecording),
          findsOneWidget);
    });

    testWidgets('shows the REC badge and elapsed time while recording',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates:
              AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RecordingControls(
              sessionId: 's3',
              serverId: 'srv-1',
              serverName: 'prod',
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('REC'), findsNothing);

      // Drive the provider directly — starting for real would call the bridge.
      container.read(recordingProvider('s3').notifier).state = RecordingStatus(
        active: true,
        recordingId: 'r1',
        startedAt: DateTime.now().subtract(const Duration(seconds: 65)),
      );
      await tester.pump();

      expect(find.text('REC'), findsOneWidget);
      expect(find.text('01:05'), findsOneWidget);
    });
  });
}
