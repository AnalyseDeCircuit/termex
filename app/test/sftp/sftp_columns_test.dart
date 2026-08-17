import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/sftp/widgets/file_list.dart';
import 'package:termex_shared/l10n/app_localizations.dart';

/// Renders [child] in a box of exactly [width], the way a docked SFTP pane
/// constrains its contents.
Widget _atWidth(double width, Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

void main() {
  group('SftpColumns.forWidth', () {
    test('shows every column when there is room', () {
      final cols = SftpColumns.forWidth(600);
      expect(cols.showSize, isTrue);
      expect(cols.showModified, isTrue);
      expect(cols.showPermissions, isTrue);
    });

    // Dropped right-to-left so the file name stays readable longest.
    test('drops permissions first', () {
      final cols = SftpColumns.forWidth(340);
      expect(cols.showSize, isTrue);
      expect(cols.showModified, isTrue);
      expect(cols.showPermissions, isFalse);
    });

    test('drops modified next', () {
      final cols = SftpColumns.forWidth(250);
      expect(cols.showSize, isTrue);
      expect(cols.showModified, isFalse);
      expect(cols.showPermissions, isFalse);
    });

    test('keeps only the name when very narrow', () {
      final cols = SftpColumns.forWidth(150);
      expect(cols.showSize, isFalse);
      expect(cols.showModified, isFalse);
      expect(cols.showPermissions, isFalse);
    });

    test('never shows a column whose left neighbour was dropped', () {
      for (var w = 60.0; w <= 700; w += 7) {
        final c = SftpColumns.forWidth(w);
        if (!c.showSize) expect(c.showModified, isFalse, reason: 'at $w');
        if (!c.showModified) {
          expect(c.showPermissions, isFalse, reason: 'at $w');
        }
      }
    });
  });

  group('narrow SFTP panes do not overflow', () {
    // Docking the panel to the side of a wide window left each pane around
    // 200px while the header still drew a fixed 315px of columns, which Flutter
    // reported as "RIGHT OVERFLOWED BY 101 PIXELS".
    testWidgets('FileListHeader lays out at a docked-pane width',
        (tester) async {
      await tester.pumpWidget(_atWidth(200, const FileListHeader()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('FileListHeader lays out when extremely narrow',
        (tester) async {
      await tester.pumpWidget(_atWidth(120, const FileListHeader()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('FileRow lays out at a docked-pane width', (tester) async {
      await tester.pumpWidget(_atWidth(
        200,
        const FileRow(
          data: FileRowData(
            name: 'a-rather-long-file-name.tar.gz',
            isDirectory: false,
            sizeBytes: 123456,
            permissions: '644',
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('SftpFilterBar lays out at a docked-pane width',
        (tester) async {
      await tester.pumpWidget(_atWidth(
        200,
        SftpFilterBar(
          showHidden: false,
          sort: SftpSort.typeFirst,
          onToggleHidden: () {},
          onSortChanged: (_) {},
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
