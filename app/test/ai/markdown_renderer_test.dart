import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/ai/panel/markdown_renderer.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

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
