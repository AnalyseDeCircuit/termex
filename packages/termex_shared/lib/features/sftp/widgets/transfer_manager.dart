/// Transfer queue manager — business logic layer for SFTP transfers.
///
/// Coordinates between the Riverpod [SftpTransferNotifier] state and the
/// FRB API calls.  UI widgets dispatch upload/download requests here instead
/// of talking to the provider directly.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/sftp_transfer_provider.dart';

export '../state/sftp_transfer_provider.dart';

/// Coordinates file transfers for a given SFTP session.
class TransferManager {
  final String sessionId;
  final Ref ref;

  TransferManager({required this.sessionId, required this.ref});

  SftpTransferNotifier get _notifier =>
      ref.read(sftpTransferProvider(sessionId).notifier);

  /// Queue a download from [remotePath] to [localPath].
  String download({
    required String remotePath,
    required String localPath,
    required String fileName,
    required int fileSize,
  }) {
    return _notifier.enqueue(
      direction: TransferDirection.download,
      localPath: localPath,
      remotePath: remotePath,
      fileName: fileName,
      totalBytes: fileSize,
    );
  }

  /// Queue an upload from [localPath] to [remotePath].
  String upload({
    required String localPath,
    required String remotePath,
    required String fileName,
    required int fileSize,
  }) {
    return _notifier.enqueue(
      direction: TransferDirection.upload,
      localPath: localPath,
      remotePath: remotePath,
      fileName: fileName,
      totalBytes: fileSize,
    );
  }

  void cancel(String transferId) => _notifier.cancel(transferId);
  void clearCompleted() => _notifier.clearCompleted();
}

final transferManagerProvider = Provider.family<TransferManager, String>(
  (ref, sessionId) => TransferManager(sessionId: sessionId, ref: ref),
);
