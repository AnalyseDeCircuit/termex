/// Mobile-unified SFTP transfer task notifier.
///
/// Wraps the per-session [SftpTransferNotifier] into a single flat list of
/// active tasks across all sessions — used by [TransferProgressOverlay] in the
/// mobile SFTP screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/sftp/state/sftp_transfer_provider.dart';

export '../features/sftp/state/sftp_transfer_provider.dart'
    show TransferItem, TransferDirection, TransferStatus;

class TransferTask {
  final String id;
  final String sessionId;
  final String fileName;
  final TransferDirection direction;
  final int totalBytes;
  final int transferredBytes;
  final TransferStatus status;
  final String? errorMessage;

  const TransferTask({
    required this.id,
    required this.sessionId,
    required this.fileName,
    required this.direction,
    required this.totalBytes,
    required this.transferredBytes,
    required this.status,
    this.errorMessage,
  });

  double get progress =>
      totalBytes > 0 ? transferredBytes / totalBytes : 0.0;

  bool get isDone =>
      status == TransferStatus.completed ||
      status == TransferStatus.failed ||
      status == TransferStatus.cancelled;

  factory TransferTask.fromItem(TransferItem item) => TransferTask(
        id: item.id,
        sessionId: item.sessionId,
        fileName: item.fileName,
        direction: item.direction,
        totalBytes: item.totalBytes,
        transferredBytes: item.transferredBytes,
        status: item.status,
        errorMessage: item.errorMessage,
      );
}

class TransferNotifier extends Notifier<List<TransferTask>> {
  @override
  List<TransferTask> build() => [];

  void addTask(TransferTask task) {
    state = [...state, task];
  }

  void updateTask(String id, TransferTask Function(TransferTask) updater) {
    state = [
      for (final t in state)
        if (t.id == id) updater(t) else t,
    ];
  }

  void removeTask(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  void clearCompleted() {
    state = state.where((t) => !t.isDone).toList();
  }
}

final transferTasksProvider =
    NotifierProvider<TransferNotifier, List<TransferTask>>(
  TransferNotifier.new,
);
