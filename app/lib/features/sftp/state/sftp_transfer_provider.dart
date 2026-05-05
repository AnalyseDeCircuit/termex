/// Riverpod provider for SFTP file transfer queue.
///
/// Tracks all active and completed transfers for a session.
/// Each transfer gets a unique ID and reports progress via state updates.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

enum TransferDirection { upload, download }
enum TransferStatus { queued, inProgress, paused, completed, failed, cancelled }

class TransferItem {
  final String id;
  final String sessionId;
  final TransferDirection direction;
  final String localPath;
  final String remotePath;
  final String fileName;
  final int totalBytes;
  final int transferredBytes;
  final TransferStatus status;
  final String? errorMessage;
  final DateTime startedAt;

  const TransferItem({
    required this.id,
    required this.sessionId,
    required this.direction,
    required this.localPath,
    required this.remotePath,
    required this.fileName,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.status = TransferStatus.queued,
    this.errorMessage,
    required this.startedAt,
  });

  double get progress =>
      totalBytes > 0 ? transferredBytes / totalBytes : 0.0;

  bool get isDone =>
      status == TransferStatus.completed ||
      status == TransferStatus.failed ||
      status == TransferStatus.cancelled;

  TransferItem copyWith({
    int? transferredBytes,
    TransferStatus? status,
    String? errorMessage,
  }) =>
      TransferItem(
        id: id,
        sessionId: sessionId,
        direction: direction,
        localPath: localPath,
        remotePath: remotePath,
        fileName: fileName,
        totalBytes: totalBytes,
        transferredBytes: transferredBytes ?? this.transferredBytes,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        startedAt: startedAt,
      );
}

class SftpTransferState {
  final List<TransferItem> items;

  const SftpTransferState({this.items = const []});

  List<TransferItem> get active =>
      items.where((t) => !t.isDone).toList();

  List<TransferItem> get completed =>
      items.where((t) => t.isDone).toList();

  bool get hasActive => active.isNotEmpty;

  SftpTransferState copyWith({List<TransferItem>? items}) =>
      SftpTransferState(items: items ?? this.items);
}

class SftpTransferNotifier
    extends FamilyNotifier<SftpTransferState, String> {
  @override
  SftpTransferState build(String sessionId) => const SftpTransferState();

  /// Enqueues a new transfer and returns its ID.
  String enqueue({
    required TransferDirection direction,
    required String localPath,
    required String remotePath,
    required String fileName,
    required int totalBytes,
  }) {
    final id = '${DateTime.now().millisecondsSinceEpoch}-$fileName';
    final item = TransferItem(
      id: id,
      sessionId: arg,
      direction: direction,
      localPath: localPath,
      remotePath: remotePath,
      fileName: fileName,
      totalBytes: totalBytes,
      startedAt: DateTime.now(),
    );
    state = state.copyWith(items: [...state.items, item]);
    _startTransfer(id);
    return id;
  }

  void updateProgress(String transferId, int transferred) {
    state = state.copyWith(
      items: state.items.map((t) {
        if (t.id != transferId) return t;
        return t.copyWith(
          transferredBytes: transferred,
          status: TransferStatus.inProgress,
        );
      }).toList(),
    );
  }

  void markCompleted(String transferId) {
    _updateStatus(transferId, TransferStatus.completed);
  }

  void markFailed(String transferId, String error) {
    state = state.copyWith(
      items: state.items.map((t) {
        if (t.id != transferId) return t;
        return t.copyWith(
            status: TransferStatus.failed, errorMessage: error);
      }).toList(),
    );
  }

  void cancel(String transferId) {
    _updateStatus(transferId, TransferStatus.cancelled);
    try {
      bridge.sftpCancelTransfer(transferId: transferId).catchError((_) {});
    } catch (_) {}
    _pollers.remove(transferId)?.cancel();
  }

  final Map<String, Timer> _pollers = {};

  void clearCompleted() {
    state = state.copyWith(
      items: state.items.where((t) => !t.isDone).toList(),
    );
  }

  void _updateStatus(String id, TransferStatus status) {
    state = state.copyWith(
      items:
          state.items.map((t) => t.id == id ? t.copyWith(status: status) : t).toList(),
    );
  }

  Future<void> _startTransfer(String id) async {
    _updateStatus(id, TransferStatus.inProgress);
    final item = state.items.firstWhere((t) => t.id == id);
    try {
      // Kick off the transfer on the Rust side.
      final transferId = id;
      if (item.direction == TransferDirection.upload) {
        await bridge.sftpUpload(
          sessionId: item.sessionId,
          localPath: item.localPath,
          remotePath: item.remotePath,
          transferId: transferId,
        );
      } else {
        await bridge.sftpDownload(
          sessionId: item.sessionId,
          remotePath: item.remotePath,
          localPath: item.localPath,
          transferId: transferId,
        );
      }

      // Poll progress until the transfer reports completion.
      _pollers[id]?.cancel();
      _pollers[id] = Timer.periodic(const Duration(milliseconds: 100), (t) async {
        try {
          final chunks = await bridge.pollSftpProgress(transferId: transferId);
          for (final p in chunks) {
            if (p.error != null) {
              t.cancel();
              _pollers.remove(id);
              markFailed(id, p.error!);
              return;
            }
            updateProgress(id, p.bytesTransferred.toInt());
            if (p.done) {
              t.cancel();
              _pollers.remove(id);
              markCompleted(id);
              return;
            }
          }
        } catch (_) {
          t.cancel();
          _pollers.remove(id);
        }
      });
    } catch (e) {
      markFailed(id, e.toString());
    }
  }
}

final sftpTransferProvider = NotifierProvider.family<SftpTransferNotifier,
    SftpTransferState, String>(SftpTransferNotifier.new);
