/// Regression tests for SFTP drag-and-drop between the local and remote panes.
///
/// The drag machinery (`SftpDragPayload` / `SftpDropTargetPane`) existed since
/// the pane was written, but neither pane ever wrapped its rows in a
/// `Draggable`: the local pane routed through a `_DraggableFileList` shell that
/// forwarded straight to `FileList`, and the remote pane used `FileList`
/// directly. Nothing was draggable, so dragging a file across panes did
/// nothing at all. These tests pin the wiring.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/sftp/widgets/file_list.dart';
import 'package:termex_shared/features/sftp/widgets/sftp_drag.dart';
import 'package:termex_shared/l10n/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SizedBox(width: 600, height: 400, child: child)),
    );

const _entries = [
  FileRowData(name: 'notes.txt', isDirectory: false, sizeBytes: 42),
  FileRowData(name: 'projects', isDirectory: true),
];

Widget _list({
  Widget Function(FileRowData, Widget)? rowWrapper,
}) =>
    FileList(
      entries: _entries,
      selectedNames: const {},
      isLoading: false,
      onToggleSelect: (_) {},
      onSelectOnly: (_) {},
      onSelectAll: () {},
      onRefresh: () {},
      onOpen: (_) {},
      onAction: (_, __) {},
      rowWrapper: rowWrapper,
    );

void main() {
  group('sftpJoin', () {
    test('joins a normal directory', () {
      expect(sftpJoin('/home/huzou', 'a.txt'), '/home/huzou/a.txt');
    });

    // Naive '$dir/$name' yields '//a.txt' at the filesystem root.
    test('does not double the separator at root', () {
      expect(sftpJoin('/', 'a.txt'), '/a.txt');
    });

    // The drop handler builds the destination as
    // sftpJoin(oppositePane.currentPath, name). When the local pane was stuck
    // on '/' (the placeholder home that was never replaced), every download
    // resolved to a root-level path and failed with "Read-only file system
    // (os error 30)" on macOS. Pinning both shapes so the destination is
    // always well-formed once the pane opens on the real home.
    test('builds a home-relative destination', () {
      expect(sftpJoin('/Users/onela', 'weft'), '/Users/onela/weft');
      expect(sftpJoin('/home/huzou', '.file'), '/home/huzou/.file');
    });
  });

  group('FileList.rowWrapper', () {
    testWidgets('rows render unwrapped when no wrapper is given',
        (tester) async {
      await tester.pumpWidget(_host(_list()));
      expect(find.byType(FileRow), findsNWidgets(2));
      expect(find.byType(Draggable<SftpDragPayload>), findsNothing);
    });

    testWidgets('wrapper receives each entry and its built row',
        (tester) async {
      final seen = <String>[];
      await tester.pumpWidget(_host(_list(
        rowWrapper: (entry, row) {
          seen.add(entry.name);
          // The row must be passed through intact — FileList resolves the
          // column layout once for the whole list, so rebuilding a FileRow
          // inside the wrapper would lose it.
          expect(row, isA<FileRow>());
          return row;
        },
      )));
      expect(seen, ['notes.txt', 'projects']);
    });

    testWidgets('wrapRowDraggable makes files draggable but not directories',
        (tester) async {
      await tester.pumpWidget(_host(_list(
        rowWrapper: (entry, row) => entry.isDirectory
            ? row
            : wrapRowDraggable(
                entry: entry,
                row: row,
                side: DragSide.local,
                absolutePath: sftpJoin('/home/huzou', entry.name),
              ),
      )));

      // Only the file is draggable: the transfer queue has no recursive
      // directory walk, so a dragged folder could not complete.
      expect(find.byType(Draggable<SftpDragPayload>), findsOneWidget);

      final draggable = tester.widget<Draggable<SftpDragPayload>>(
        find.byType(Draggable<SftpDragPayload>),
      );
      expect(draggable.data!.side, DragSide.local);
      expect(draggable.data!.file.name, 'notes.txt');
      expect(draggable.data!.absolutePath, '/home/huzou/notes.txt');
    });
  });

  group('SftpDragPayload', () {
    test('carries the origin side so the drop target can reject same-side',
        () {
      const local = SftpDragPayload(
        side: DragSide.local,
        file: FileRowData(name: 'a.txt', isDirectory: false),
        absolutePath: '/tmp/a.txt',
      );
      // SftpDropTargetPane.onWillAcceptWithDetails uses exactly this
      // comparison to refuse a drag that never left its own pane.
      expect(local.side != DragSide.local, isFalse);
      expect(local.side != DragSide.remote, isTrue);
    });
  });
}
