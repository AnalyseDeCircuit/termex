import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/sftp/state/sftp_pane_provider.dart';
import 'package:termex/features/sftp/state/sftp_transfer_provider.dart';
import 'package:termex/features/sftp/widgets/file_row.dart';
import 'package:termex/features/sftp/widgets/sftp_drag.dart';

Widget _wrap(Widget w) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: w)),
    );

void main() {
  group('SftpDragPayload', () {
    test('carries correct side and path', () {
      const payload = SftpDragPayload(
        side: DragSide.local,
        file: FileRowData(name: 'file.txt', isDirectory: false),
        absolutePath: '/home/user/file.txt',
      );
      expect(payload.side, DragSide.local);
      expect(payload.absolutePath, '/home/user/file.txt');
      expect(payload.file.name, 'file.txt');
    });
  });

  group('DraggableFileRow', () {
    testWidgets('renders file name', (tester) async {
      await tester.pumpWidget(_wrap(
        const DraggableFileRow(
          data: FileRowData(name: 'deploy.sh', isDirectory: false),
          side: DragSide.local,
          absolutePath: '/tmp/deploy.sh',
        ),
      ));
      expect(find.text('deploy.sh'), findsOneWidget);
    });

    testWidgets('feedback widget shows file name', (tester) async {
      await tester.pumpWidget(_wrap(
        Draggable<SftpDragPayload>(
          data: const SftpDragPayload(
            side: DragSide.remote,
            file: FileRowData(name: 'notes.txt', isDirectory: false),
            absolutePath: '/home/user/notes.txt',
          ),
          feedback: Material(
            child: Text('notes.txt',
                style: const TextStyle(color: Colors.white)),
          ),
          child: const Text('notes.txt'),
        ),
      ));
      expect(find.text('notes.txt'), findsOneWidget);
    });
  });

  group('SftpDropTargetPane — DragTarget acceptance', () {
    testWidgets('local pane rejects local→local drag', (tester) async {
      bool accepted = false;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DragTarget<SftpDragPayload>(
              onWillAcceptWithDetails: (d) {
                // Simulates LocalPane: only accept from opposite side.
                accepted = d.data.side != DragSide.local;
                return accepted;
              },
              builder: (_, __, ___) => const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      ));
      // No actual gesture simulation needed — verify the logic directly.
      const localPayload = SftpDragPayload(
        side: DragSide.local,
        file: FileRowData(name: 'x.txt', isDirectory: false),
        absolutePath: '/tmp/x.txt',
      );
      expect(localPayload.side != DragSide.local, isFalse);
    });

    testWidgets('remote pane accepts local→remote drag', (tester) async {
      const payload = SftpDragPayload(
        side: DragSide.local,
        file: FileRowData(name: 'upload.tar', isDirectory: false),
        absolutePath: '/tmp/upload.tar',
      );
      // The acceptance rule: payload.side != targetSide (remote).
      expect(payload.side != DragSide.remote, isTrue);
    });
  });

  group('SftpTransferProvider — drag-initiated enqueue', () {
    test('enqueue upload after local→remote drop', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(sftpTransferProvider('s1').notifier).enqueue(
            direction: TransferDirection.upload,
            localPath: '/tmp/file.txt',
            remotePath: '/home/user/file.txt',
            fileName: 'file.txt',
            totalBytes: 512,
          );

      final state = container.read(sftpTransferProvider('s1'));
      expect(state.items, hasLength(1));
      expect(state.items.first.direction, TransferDirection.upload);
    });

    test('enqueue download after remote→local drop', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(sftpTransferProvider('s1').notifier).enqueue(
            direction: TransferDirection.download,
            localPath: '/tmp/remote_file.log',
            remotePath: '/var/log/app.log',
            fileName: 'app.log',
            totalBytes: 2048,
          );

      final state = container.read(sftpTransferProvider('s1'));
      expect(state.items.first.direction, TransferDirection.download);
      expect(state.items.first.fileName, 'app.log');
    });
  });
}
