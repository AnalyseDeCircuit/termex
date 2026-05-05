/// SFTP drag-and-drop support.
///
/// Covers three scenarios (§5.4):
///   1. Local → Remote : drag a local file row and drop onto the remote pane
///   2. Remote → Local : drag a remote file row and drop onto the local pane
///   3. System → Remote: drop external files (from OS) onto the remote pane
///                       handled via `desktop_drop` DropTarget
library;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../state/sftp_pane_provider.dart';
import '../state/sftp_transfer_provider.dart';
import 'file_row.dart';

// ── Drag payload ──────────────────────────────────────────────────────────────

/// Identifies the origin side of a drag operation.
enum DragSide { local, remote }

/// Payload carried by a dragged file row.
class SftpDragPayload {
  final DragSide side;
  final FileRowData file;

  /// Absolute path of the file on its origin side.
  final String absolutePath;

  const SftpDragPayload({
    required this.side,
    required this.file,
    required this.absolutePath,
  });
}

// ── Draggable row ─────────────────────────────────────────────────────────────

/// A [FileRow] wrapped in a [Draggable] that carries [SftpDragPayload].
///
/// During dragging a semi-transparent clone of the row follows the pointer.
class DraggableFileRow extends StatelessWidget {
  final FileRowData data;
  final bool isSelected;
  final DragSide side;
  final String absolutePath;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onSecondaryTap;

  const DraggableFileRow({
    super.key,
    required this.data,
    required this.side,
    required this.absolutePath,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final payload = SftpDragPayload(
      side: side,
      file: data,
      absolutePath: absolutePath,
    );

    return Draggable<SftpDragPayload>(
      data: payload,
      feedback: _DragFeedback(name: data.name, side: side),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: FileRow(data: data, isSelected: isSelected),
      ),
      child: FileRow(
        data: data,
        isSelected: isSelected,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onSecondaryTap: onSecondaryTap,
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  final String name;
  final DragSide side;

  const _DragFeedback({required this.name, required this.side});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: TermexColors.backgroundSecondary.withOpacity(0.9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: TermexColors.primary.withOpacity(0.6)),
          boxShadow: const [
            BoxShadow(color: Color(0x50000000), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              side == DragSide.local
                  ? Icons.upload_outlined
                  : Icons.download_outlined,
              size: 14,
              color: TermexColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                color: TermexColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drop target pane ──────────────────────────────────────────────────────────

/// Wraps a pane widget in a [DragTarget] that accepts [SftpDragPayload]
/// from the opposite side, and also wraps in a [DropTarget] (desktop_drop)
/// for system file drops onto the remote pane.
class SftpDropTargetPane extends ConsumerStatefulWidget {
  final String sessionId;

  /// Which side THIS pane represents.
  final DragSide side;

  /// The pane content to display inside the drop target.
  final Widget child;

  const SftpDropTargetPane({
    super.key,
    required this.sessionId,
    required this.side,
    required this.child,
  });

  @override
  ConsumerState<SftpDropTargetPane> createState() =>
      _SftpDropTargetPaneState();
}

class _SftpDropTargetPaneState extends ConsumerState<SftpDropTargetPane> {
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    Widget content = DragTarget<SftpDragPayload>(
      onWillAcceptWithDetails: (details) =>
          // Only accept drags from the opposite side.
          details.data.side != widget.side,
      onAcceptWithDetails: (details) => _handleDrop(details.data),
      onLeave: (_) => setState(() => _isDragOver = false),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        if (hovering != _isDragOver) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => setState(() => _isDragOver = hovering));
        }
        return _DropOverlay(isOver: _isDragOver, child: widget.child);
      },
    );

    // System file drag-in: only make sense for the remote pane.
    if (widget.side == DragSide.remote) {
      content = DropTarget(
        onDragDone: _handleSystemDrop,
        onDragEntered: (_) => setState(() => _isDragOver = true),
        onDragExited: (_) => setState(() => _isDragOver = false),
        child: content,
      );
    }

    return content;
  }

  // ── Handlers ────────────────────────────────────────────────────────────────

  void _handleDrop(SftpDragPayload payload) {
    final paneState = ref.read(sftpPaneProvider(widget.sessionId));
    final notifier = ref.read(sftpTransferProvider(widget.sessionId).notifier);

    if (payload.side == DragSide.local && widget.side == DragSide.remote) {
      // Upload: local → remote
      final remoteDir = paneState.remote.currentPath;
      final remotePath = '$remoteDir/${payload.file.name}';
      notifier.enqueue(
        direction: TransferDirection.upload,
        localPath: payload.absolutePath,
        remotePath: remotePath,
        fileName: payload.file.name,
        totalBytes: payload.file.sizeBytes ?? 0,
      );
    } else if (payload.side == DragSide.remote && widget.side == DragSide.local) {
      // Download: remote → local
      final localDir = paneState.local.currentPath;
      final localPath = '$localDir/${payload.file.name}';
      notifier.enqueue(
        direction: TransferDirection.download,
        localPath: localPath,
        remotePath: payload.absolutePath,
        fileName: payload.file.name,
        totalBytes: payload.file.sizeBytes ?? 0,
      );
    }
  }

  void _handleSystemDrop(DropDoneDetails details) {
    // System files dragged from OS into the remote pane → upload each.
    final paneState = ref.read(sftpPaneProvider(widget.sessionId));
    final notifier = ref.read(sftpTransferProvider(widget.sessionId).notifier);
    final remoteDir = paneState.remote.currentPath;

    for (final xFile in details.files) {
      final name = xFile.name;
      final remotePath = '$remoteDir/$name';
      notifier.enqueue(
        direction: TransferDirection.upload,
        localPath: xFile.path,
        remotePath: remotePath,
        fileName: name,
        totalBytes: 0, // size unknown until transfer starts
      );
    }
  }
}

class _DropOverlay extends StatelessWidget {
  final bool isOver;
  final Widget child;

  const _DropOverlay({required this.isOver, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isOver)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: TermexColors.primary.withOpacity(0.12),
                  border: Border.all(
                    color: TermexColors.primary.withOpacity(0.7),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Text(
                    '松开以传输',
                    style: TextStyle(
                      color: TermexColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
