import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/sftp/widgets/file_row.dart';

Widget wrapWidget(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  group('FileRow', () {
    testWidgets('renders file name', (tester) async {
      await tester.pumpWidget(wrapWidget(
        FileRow(
          data: const FileRowData(
            name: 'README.md',
            isDirectory: false,
            sizeBytes: 1024,
          ),
        ),
      ));
      expect(find.text('README.md'), findsOneWidget);
    });

    testWidgets('renders directory name', (tester) async {
      await tester.pumpWidget(wrapWidget(
        FileRow(
          data: const FileRowData(
            name: 'src',
            isDirectory: true,
          ),
        ),
      ));
      expect(find.text('src'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(wrapWidget(
        FileRow(
          data: const FileRowData(name: 'file.txt', isDirectory: false),
          onTap: () => tapped = true,
        ),
      ));
      await tester.tap(find.byType(FileRow));
      expect(tapped, isTrue);
    });

    testWidgets('shows selected background', (tester) async {
      await tester.pumpWidget(wrapWidget(
        FileRow(
          data: const FileRowData(name: 'file.txt', isDirectory: false),
          isSelected: true,
        ),
      ));
      // No crash and the widget renders.
      expect(find.text('file.txt'), findsOneWidget);
    });
  });
}
