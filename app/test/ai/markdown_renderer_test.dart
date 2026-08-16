import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/ai/panel/markdown_renderer.dart';
import 'package:termex_shared/l10n/app_localizations.dart';

// v0.79.0 i18n: fenced code blocks render CodeBlock, which now calls
// AppLocalizations.of(context) for its run/copy labels — supply the
// delegates so the lookup resolves in the test harness.
Widget _wrap(Widget w) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: w),
    );

void main() {
  group('MarkdownRenderer', () {
    testWidgets('renders plain text', (tester) async {
      await tester.pumpWidget(_wrap(
        const MarkdownRenderer(text: 'Hello world'),
      ));
      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('renders fenced code block', (tester) async {
      await tester.pumpWidget(_wrap(
        const MarkdownRenderer(text: '```bash\nls -la\n```'),
      ));
      // CodeBlock renders the code text
      expect(find.text('ls -la'), findsOneWidget);
    });

    testWidgets('renders heading text', (tester) async {
      await tester.pumpWidget(_wrap(
        const MarkdownRenderer(text: '# My Title'),
      ));
      expect(find.text('My Title'), findsOneWidget);
    });

    testWidgets('renders empty string without crash', (tester) async {
      await tester.pumpWidget(_wrap(
        const MarkdownRenderer(text: ''),
      ));
      // No exception = pass
    });
  });
}
