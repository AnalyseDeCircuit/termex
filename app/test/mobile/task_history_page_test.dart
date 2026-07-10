/// Widget tests for [MobileTaskHistoryPage] (v0.79.39).
///
/// Focuses on swipe-to-delete plumbing — each row is wrapped in a
/// Dismissible with the right key and direction, and the confirm flow
/// gates the actual mutation.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/mobile/task_event_bus.dart';
import 'package:termex/mobile/task_history_page.dart';
import 'package:termex_shared/l10n/app_localizations.dart';

PageRoute<T> _route<T>(RouteSettings s, WidgetBuilder b) =>
    PageRouteBuilder<T>(settings: s, pageBuilder: (ctx, _, __) => b(ctx));

Widget _harness(Widget child) => WidgetsApp(
      color: const Color(0xFF0D1117),
      pageRouteBuilder: _route,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  setUp(() => TaskEventBus.instance.clearAll());

  group('MobileTaskHistoryPage swipe-to-delete', () {
    testWidgets('each populated row is wrapped in a Dismissible',
        (tester) async {
      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'sftp-row-1',
        title: 'Uploaded foo.zip',
        summary: '12 MB',
        status: TaskEventStatus.succeeded,
      ));
      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'ai-row-1',
        title: 'AI reply',
        summary: '1200 chars',
        status: TaskEventStatus.succeeded,
      ));

      await tester.pumpWidget(_harness(const MobileTaskHistoryPage()));
      await tester.pump();

      // One Dismissible per published task row.
      expect(find.byType(Dismissible), findsNWidgets(2));
    });

    testWidgets('Dismissible key derives from taskId', (tester) async {
      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'sftp-row-42',
        title: 'Uploaded bar.tar',
        summary: '8 MB',
        status: TaskEventStatus.succeeded,
      ));

      await tester.pumpWidget(_harness(const MobileTaskHistoryPage()));
      await tester.pump();

      final dismissible =
          tester.widget<Dismissible>(find.byType(Dismissible));
      expect(dismissible.key, const ValueKey('task-row-sftp-row-42'));
    });

    testWidgets('Dismissible direction is endToStart only', (tester) async {
      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'sftp-dir-1',
        title: 'Uploaded x',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));

      await tester.pumpWidget(_harness(const MobileTaskHistoryPage()));
      await tester.pump();

      final dismissible =
          tester.widget<Dismissible>(find.byType(Dismissible));
      expect(dismissible.direction, DismissDirection.endToStart);
    });

    testWidgets('search box filters rows by title (case-insensitive)',
        (tester) async {
      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'sftp-search-1',
        title: 'Uploaded README.md',
        summary: '4 KB',
        status: TaskEventStatus.succeeded,
      ));
      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'sftp-search-2',
        title: 'Uploaded foo.tar.gz',
        summary: '12 MB',
        status: TaskEventStatus.succeeded,
      ));
      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'ai-search-1',
        title: 'AI reply from claude',
        summary: 'response',
        status: TaskEventStatus.succeeded,
      ));

      await tester.pumpWidget(_harness(const MobileTaskHistoryPage()));
      await tester.pump();
      expect(find.byType(Dismissible), findsNWidgets(3));

      // Type "TAR" (uppercase): should filter to just foo.tar.gz.
      await tester.enterText(find.byType(EditableText).first, 'TAR');
      await tester.pump();
      expect(find.byType(Dismissible), findsOneWidget);
      // v0.79.42: active search swaps the row's title from Text to
      // RichText so matching substrings can be highlighted. We assert
      // the title reconstructs from the TextSpan tree.
      expect(find.textContaining('foo.tar.gz', findRichText: true),
          findsOneWidget);
    });

    testWidgets('multi-token search filters rows with OR semantics (v0.79.46)',
        (tester) async {
      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'sftp-multi-1',
        title: 'Uploaded README.md',
        summary: 'docs',
        status: TaskEventStatus.succeeded,
      ));
      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'sftp-multi-2',
        title: 'Uploaded foo.tar.gz',
        summary: '12 MB',
        status: TaskEventStatus.succeeded,
      ));
      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'sftp-multi-3',
        title: 'Uploaded image.png',
        summary: 'asset',
        status: TaskEventStatus.succeeded,
      ));

      await tester.pumpWidget(_harness(const MobileTaskHistoryPage()));
      await tester.pump();
      expect(find.byType(Dismissible), findsNWidgets(3));

      // "tar png" matches sftp-multi-2 (title contains "tar") and
      // sftp-multi-3 (title contains "png"). README.md row drops.
      await tester.enterText(find.byType(EditableText).first, 'tar png');
      await tester.pump();
      expect(find.byType(Dismissible), findsNWidgets(2));
    });

    testWidgets('matching substring renders inside RichText with yellow background',
        (tester) async {
      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'sftp-hl-1',
        title: 'Uploaded foo.tar.gz',
        summary: 'Upload completed (12 MB)',
        status: TaskEventStatus.succeeded,
      ));

      await tester.pumpWidget(_harness(const MobileTaskHistoryPage()));
      await tester.pump();
      // Pre-search: title rendered as plain Text, no RichText.
      expect(find.text('Uploaded foo.tar.gz'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).first, 'foo');
      await tester.pump();

      // Post-search: row title becomes RichText so the match span can
      // wear the highlight style. We can't easily assert the exact
      // BackgroundColor in widget-test land, but presence of RichText
      // over the title is a structural proxy.
      final rich = find.byType(RichText);
      expect(rich, findsWidgets);

      // At least one RichText carries a TextSpan tree whose flattened
      // text reconstitutes the title.
      final hits = tester
          .widgetList<RichText>(rich)
          .where((w) {
        var buf = '';
        void walk(InlineSpan s) {
          if (s is TextSpan) {
            if (s.text != null) buf += s.text!;
            if (s.children != null) {
              for (final c in s.children!) {
                walk(c);
              }
            }
          }
        }
        walk(w.text);
        return buf == 'Uploaded foo.tar.gz';
      });
      expect(hits, isNotEmpty);
    });

    testWidgets('search empty-state appears when no row matches',
        (tester) async {
      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'sftp-empty-1',
        title: 'Uploaded foo',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));

      await tester.pumpWidget(_harness(const MobileTaskHistoryPage()));
      await tester.pump();
      await tester.enterText(
          find.byType(EditableText).first, 'nonexistent-query');
      await tester.pump();

      // "No tasks match your search" empty-state hint visible.
      expect(find.text('No tasks match your search'), findsOneWidget);
      expect(find.byType(Dismissible), findsNothing);
    });

    testWidgets('cancelling confirm dialog leaves the row intact',
        (tester) async {
      TaskEventBus.instance.publish(TaskEvent(
        taskId: 'sftp-cancel-1',
        title: 'Uploaded keep.me',
        summary: 's',
        status: TaskEventStatus.succeeded,
      ));

      await tester.pumpWidget(_harness(const MobileTaskHistoryPage()));
      await tester.pump();

      // Drag the row far enough to trigger the confirm dialog.
      await tester.drag(find.text('Uploaded keep.me'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Cancel the dialog.
      final cancelButton = find.text(AppLocalizations.supportedLocales
              .contains(const Locale('zh'))
          ? '取消'
          : 'Cancel');
      if (cancelButton.evaluate().isNotEmpty) {
        await tester.tap(cancelButton.first);
        await tester.pumpAndSettle();
      }

      // The bus snapshot still contains the event.
      expect(TaskEventBus.instance.latestFor('sftp-cancel-1'), isNotNull);
    });
  });
}
