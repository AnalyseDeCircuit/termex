/// Local filesystem pane for the SFTP dual-pane browser.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../dialogs/new_file_dialog.dart';
import '../dialogs/rename_dialog.dart';
import '../state/sftp_pane_provider.dart';
import '../state/sftp_transfer_provider.dart';
import 'file_list.dart';
import 'path_bar.dart';
import 'sftp_drag.dart';

/// Left pane — browses the local filesystem.
///
/// Wrapped in an [SftpDropTargetPane] so remote files can be dropped here
/// to trigger a download.
class LocalPane extends ConsumerStatefulWidget {
  final String sessionId;
  final String? remoteCurrentPath;

  const LocalPane({
    super.key,
    required this.sessionId,
    this.remoteCurrentPath,
  });

  @override
  ConsumerState<LocalPane> createState() => _LocalPaneState();
}

class _LocalPaneState extends ConsumerState<LocalPane> {
  List<FileRowData> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentDir();
  }

  Future<void> _loadCurrentDir() async {
    final notifier = ref.read(sftpPaneProvider(widget.sessionId).notifier);
    final currentPath = ref
        .read(sftpPaneProvider(widget.sessionId))
        .local
        .currentPath;
    notifier.setLocalLoading(true);
    try {
      final entries = await bridge.localListDir(path: currentPath);
      if (!mounted) return;
      setState(() {
        _entries = entries
            .map((e) => FileRowData(
                  name: e.name,
                  isDirectory: e.isDir,
                  sizeBytes: e.size.toInt(),
                  modifiedAt: e.modifiedAt == null
                      ? null
                      : DateTime.fromMillisecondsSinceEpoch(
                          e.modifiedAt!.toInt() * 1000),
                  permissions: e.permissions == null
                      ? null
                      : e.permissions!.toRadixString(8),
                ))
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _entries = []);
    } finally {
      notifier.setLocalLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paneState = ref.watch(sftpPaneProvider(widget.sessionId));
    final local = paneState.local;

    return SftpDropTargetPane(
      sessionId: widget.sessionId,
      side: DragSide.local,
      child: Column(
        children: [
          PathBar(
            path: local.currentPath,
            onNavigate: (path) {
              ref
                  .read(sftpPaneProvider(widget.sessionId).notifier)
                  .navigateLocal(path);
              _loadCurrentDir();
            },
            onRefresh: _loadCurrentDir,
          ),
          const FileListHeader(),
          Expanded(
            child: _DraggableFileList(
              sessionId: widget.sessionId,
              entries: _entries,
              selectedNames: local.selectedNames,
              isLoading: local.isLoading,
              errorMessage: local.errorMessage,
              side: DragSide.local,
              currentPath: local.currentPath,
              onToggleSelect: (name) => ref
                  .read(sftpPaneProvider(widget.sessionId).notifier)
                  .toggleLocalSelection(name),
              onOpen: (entry) async {
                if (entry.isDirectory) {
                  ref
                      .read(sftpPaneProvider(widget.sessionId).notifier)
                      .navigateLocal('${local.currentPath}/${entry.name}');
                  await _loadCurrentDir();
                }
              },
              onAction: (entry, action) =>
                  _handleAction(context, entry, action),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, FileRowData entry, FileAction action) async {
    switch (action) {
      case FileAction.upload:
        final remotePath =
            '${widget.remoteCurrentPath ?? '~'}/${entry.name}';
        ref.read(sftpTransferProvider(widget.sessionId).notifier).enqueue(
              direction: TransferDirection.upload,
              localPath:
                  '${ref.read(sftpPaneProvider(widget.sessionId)).local.currentPath}/${entry.name}',
              remotePath: remotePath,
              fileName: entry.name,
              totalBytes: entry.sizeBytes ?? 0,
            );
      case FileAction.rename:
        if (!context.mounted) return;
        final newName =
            await showRenameDialog(context, currentName: entry.name);
        if (newName != null) {
          final dir = ref
              .read(sftpPaneProvider(widget.sessionId))
              .local
              .currentPath;
          await bridge.localRename(
            from: '$dir/${entry.name}',
            to: '$dir/$newName',
          );
          await _loadCurrentDir();
        }
      case FileAction.delete:
        final dir = ref
            .read(sftpPaneProvider(widget.sessionId))
            .local
            .currentPath;
        final target = '$dir/${entry.name}';
        if (entry.isDirectory) {
          await bridge.localRmdir(path: target);
        } else {
          await bridge.localDelete(path: target);
        }
        await _loadCurrentDir();
      case FileAction.newFile:
        if (!context.mounted) return;
        final name = await showNewFileDialog(context);
        if (name != null) {
          final dir = ref
              .read(sftpPaneProvider(widget.sessionId))
              .local
              .currentPath;
          await bridge.localCreateFile(path: '$dir/$name');
          await _loadCurrentDir();
        }
      case FileAction.newFolder:
        if (!context.mounted) return;
        final name = await showNewFolderDialog(context);
        if (name != null) {
          final dir = ref
              .read(sftpPaneProvider(widget.sessionId))
              .local
              .currentPath;
          await bridge.localMkdir(path: '$dir/$name');
          await _loadCurrentDir();
        }
      default:
        break;
    }
  }
}

// ── Draggable file list ───────────────────────────────────────────────────────

class _DraggableFileList extends StatelessWidget {
  final String sessionId;
  final List<FileRowData> entries;
  final Set<String> selectedNames;
  final bool isLoading;
  final String? errorMessage;
  final DragSide side;
  final String currentPath;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<FileRowData> onOpen;
  final void Function(FileRowData, FileAction) onAction;

  const _DraggableFileList({
    required this.sessionId,
    required this.entries,
    required this.selectedNames,
    required this.isLoading,
    this.errorMessage,
    required this.side,
    required this.currentPath,
    required this.onToggleSelect,
    required this.onOpen,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    // Delegate loading/error/empty states to FileList, then override itemBuilder.
    return FileList(
      entries: entries,
      selectedNames: selectedNames,
      isLoading: isLoading,
      errorMessage: errorMessage,
      onToggleSelect: onToggleSelect,
      onOpen: onOpen,
      onAction: onAction,
    );
  }
}
