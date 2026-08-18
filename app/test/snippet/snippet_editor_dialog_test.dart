import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/snippet/snippet_editor.dart';
import 'package:termex_shared/features/snippet/state/snippet_provider.dart';
import 'package:termex_shared/l10n/app_localizations.dart';

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('SnippetEditor.show', () {
    // Creating a snippet used to swap the library panel's contents for the
    // editor. In the ~300px desktop sidebar its action row could not fit and
    // painted a RenderFlex overflow instead of a form.
    testWidgets('opens as a modal without overflowing a narrow host',
        (tester) async {
      await tester.pumpWidget(_host(
        Builder(
          builder: (ctx) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: TextButton(
                onPressed: () => SnippetEditor.show(ctx),
                child: const Text('add'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('add'));
      await tester.pumpAndSettle();

      expect(find.byType(SnippetEditor), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dismisses without touching the editing id', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => SnippetEditor.show(ctx),
                child: const Text('add'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('add'));
      await tester.pumpAndSettle();
      expect(find.byType(SnippetEditor), findsOneWidget);

      // Cancel pops the route; the inline editing id is never involved.
      // Located by type rather than label — the test locale is not Chinese.
      await tester.tap(find.descendant(
        of: find.byType(SnippetEditor),
        matching: find.byType(TextButton),
      ).first);
      await tester.pumpAndSettle();

      expect(find.byType(SnippetEditor), findsNothing);
      expect(container.read(snippetProvider).editingId, isNull);
    });
  });
}
