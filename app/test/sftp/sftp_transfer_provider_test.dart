import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/sftp/state/sftp_transfer_provider.dart';

void main() {
  ProviderContainer makeContainer() =>
      ProviderContainer(overrides: []);

  group('SftpTransferProvider', () {
    test('starts empty', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final state = c.read(sftpTransferProvider('s1'));
      expect(state.items, isEmpty);
    });

    test('enqueue adds an item', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      c.read(sftpTransferProvider('s1').notifier).enqueue(
            direction: TransferDirection.download,
            localPath: '/tmp/file.txt',
            remotePath: '/home/user/file.txt',
            fileName: 'file.txt',
            totalBytes: 1024,
          );
      // Stub immediately completes.
      final state = c.read(sftpTransferProvider('s1'));
      expect(state.items, hasLength(1));
    });

    test('cancel sets status to cancelled', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(sftpTransferProvider('s1').notifier);
      final id = notifier.enqueue(
        direction: TransferDirection.upload,
        localPath: '/tmp/a.txt',
        remotePath: '/home/user/a.txt',
        fileName: 'a.txt',
        totalBytes: 512,
      );
      notifier.cancel(id);
      final state = c.read(sftpTransferProvider('s1'));
      final item = state.items.firstWhere((i) => i.id == id);
      expect(item.status, TransferStatus.cancelled);
    });

    test('clearCompleted removes done items', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(sftpTransferProvider('s1').notifier);
      notifier.enqueue(
        direction: TransferDirection.download,
        localPath: '/tmp/b.txt',
        remotePath: '/home/user/b.txt',
        fileName: 'b.txt',
        totalBytes: 100,
      );
      // Stub completes immediately.
      notifier.clearCompleted();
      final state = c.read(sftpTransferProvider('s1'));
      expect(state.completed, isEmpty);
    });

    test('updateProgress updates transferredBytes', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(sftpTransferProvider('s1').notifier);
      final id = notifier.enqueue(
        direction: TransferDirection.download,
        localPath: '/tmp/c.txt',
        remotePath: '/home/user/c.txt',
        fileName: 'c.txt',
        totalBytes: 2000,
      );
      notifier.updateProgress(id, 500);
      final state = c.read(sftpTransferProvider('s1'));
      final item = state.items.firstWhere((i) => i.id == id);
      expect(item.transferredBytes, 500);
    });

    test('markFailed stores error message', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(sftpTransferProvider('s1').notifier);
      final id = notifier.enqueue(
        direction: TransferDirection.upload,
        localPath: '/tmp/d.txt',
        remotePath: '/home/user/d.txt',
        fileName: 'd.txt',
        totalBytes: 512,
      );
      notifier.markFailed(id, 'connection lost');
      final state = c.read(sftpTransferProvider('s1'));
      final item = state.items.firstWhere((i) => i.id == id);
      expect(item.status, TransferStatus.failed);
      expect(item.errorMessage, 'connection lost');
    });

    test('separate sessionIds have independent state', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      c.read(sftpTransferProvider('s1').notifier).enqueue(
            direction: TransferDirection.download,
            localPath: '/tmp/x.txt',
            remotePath: '/x.txt',
            fileName: 'x.txt',
            totalBytes: 1,
          );
      final s2State = c.read(sftpTransferProvider('s2'));
      expect(s2State.items, isEmpty);
    });
  });
}
