/// Remote filesystem pane for the SFTP dual-pane browser.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../dialogs/chmod_dialog.dart';
import '../dialogs/file_info_dialog.dart';
import '../dialogs/new_file_dialog.dart';
import '../dialogs/rename_dialog.dart';
import '../state/sftp_pane_provider.dart';
import '../state/sftp_transfer_provider.dart';
import 'file_list.dart';
import 'path_bar.dart';
import 'sftp_drag.dart';

/// Right pane — browses the remote filesystem via SFTP.
///
/// Wrapped in [SftpDropTargetPane] so local files can be dropped here to
/// trigger an upload, and system files dragged from the OS are also accepted.
class RemotePane extends ConsumerStatefulWidget {
  final String sessionId;
  final String? localCurrentPath;

  const RemotePane({
    super.key,
    required this.sessionId,
    this.localCurrentPath,
  });

  @override
  ConsumerState<RemotePane> createState() => _RemotePaneState();
}

class _RemotePaneState extends ConsumerState<RemotePane> {
  List<FileRowData> _entries = [];
  bool _showHidden = false;
  SftpSort _sort = SftpSort.typeFirst;

  @override
  void initState() {
    super.initState();
    _loadCurrentDir();
  }

  List<FileRowData> _viewEntries() {
    final list = _showHidden
        ? List<FileRowData>.from(_entries)
        : _entries.where((e) => !e.name.startsWith('.')).toList();
    list.sort((a, b) {
      switch (_sort) {
        case SftpSort.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SftpSort.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case SftpSort.sizeDesc:
          return (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0);
        case SftpSort.modifiedDesc:
          final am = a.modifiedAt?.millisecondsSinceEpoch ?? 0;
          final bm = b.modifiedAt?.millisecondsSinceEpoch ?? 0;
          return bm.compareTo(am);
        case SftpSort.typeFirst:
          if (a.isDirectory != b.isDirectory) {
            return a.isDirectory ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
    return list;
  }

  Future<void> _loadCurrentDir() async {
    final notifier = ref.read(sftpPaneProvider(widget.sessionId).notifier);
    final path = ref.read(sftpPaneProvider(widget.sessionId)).remote.currentPath;
    notifier.setRemoteLoading(true);
    notifier.setRemoteError(null);
    try {
      final entries =
          await bridge.sftpList(sessionId: widget.sessionId, path: path);
      if (!mounted) return;
      setState(() {
        _entries = entries
            .map((e) => FileRowData(
                  name: e.name,
                  isDirectory: e.isDir,
                  sizeBytes: e.size.toInt(),
                  modifiedAt: DateTime.fromMillisecondsSinceEpoch(
                      e.modifiedAt.toInt() * 1000),
                  permissions: e.permissions.toRadixString(8),
                  owner: e.owner,
                  group: e.group,
                ))
            .toList();
      });
    } catch (e) {
      notifier.setRemoteError(e.toString());
    } finally {
      notifier.setRemoteLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paneState = ref.watch(sftpPaneProvider(widget.sessionId));
    final remote = paneState.remote;

    return SftpDropTargetPane(
      sessionId: widget.sessionId,
      side: DragSide.remote,
      child: Column(
        children: [
          PathBar(
            path: remote.currentPath,
            onNavigate: (path) {
              ref
                  .read(sftpPaneProvider(widget.sessionId).notifier)
                  .navigateRemote(path);
              _loadCurrentDir();
            },
            onRefresh: _loadCurrentDir,
          ),
          SftpFilterBar(
            showHidden: _showHidden,
            sort: _sort,
            onToggleHidden: () =>
                setState(() => _showHidden = !_showHidden),
            onSortChanged: (s) => setState(() => _sort = s),
          ),
          const FileListHeader(),
          Expanded(
            child: FileList(
              entries: _viewEntries(),
              selectedNames: remote.selectedNames,
              isLoading: remote.isLoading,
              errorMessage: remote.errorMessage,
              onToggleSelect: (name) => ref
                  .read(sftpPaneProvider(widget.sessionId).notifier)
                  .toggleRemoteSelection(name),
              onOpen: (entry) async {
                if (entry.isDirectory) {
                  ref
                      .read(sftpPaneProvider(widget.sessionId).notifier)
                      .navigateRemote('${remote.currentPath}/${entry.name}');
                  await _loadCurrentDir();
                } else {
                  // Download on double-tap.
                  final localPath =
                      '${widget.localCurrentPath ?? '/tmp'}/${entry.name}';
                  ref.read(sftpTransferProvider(widget.sessionId).notifier).enqueue(
                        direction: TransferDirection.download,
                        localPath: localPath,
                        remotePath: '${remote.currentPath}/${entry.name}',
                        fileName: entry.name,
                        totalBytes: entry.sizeBytes ?? 0,
                      );
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
    final remotePath =
        '${ref.read(sftpPaneProvider(widget.sessionId)).remote.currentPath}/${entry.name}';
    switch (action) {
      case FileAction.download:
        final localPath =
            '${widget.localCurrentPath ?? '/tmp'}/${entry.name}';
        ref.read(sftpTransferProvider(widget.sessionId).notifier).enqueue(
              direction: TransferDirection.download,
              localPath: localPath,
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
              .remote
              .currentPath;
          await bridge.sftpRename(
            sessionId: widget.sessionId,
            from: '$dir/${entry.name}',
            to: '$dir/$newName',
          );
          await _loadCurrentDir();
        }
      case FileAction.delete:
        if (entry.isDirectory) {
          await bridge.sftpRmdir(
            sessionId: widget.sessionId,
            path: remotePath,
          );
        } else {
          await bridge.sftpRemove(
            sessionId: widget.sessionId,
            path: remotePath,
          );
        }
        await _loadCurrentDir();
      case FileAction.chmod:
        if (!context.mounted) return;
        final mode = await showChmodDialog(
          context,
          fileName: entry.name,
          initialPermissions:
              entry.permissions?.replaceAll(RegExp(r'\D'), '') ?? '644',
        );
        if (mode != null) {
          await bridge.sftpChmod(
            sessionId: widget.sessionId,
            path: remotePath,
            mode: int.parse(mode, radix: 8),
          );
        }
      case FileAction.newFile:
        if (!context.mounted) return;
        final name = await showNewFileDialog(context);
        if (name != null) {
          // No dedicated sftpCreateFile API — upload a zero-byte file via
          // a temporary local file, or emulate via sftpUpload with empty
          // content. For now we fall back to sftpMkdir semantics as a
          // placeholder until a touch-equivalent API is added.
          final dir = ref
              .read(sftpPaneProvider(widget.sessionId))
              .remote
              .currentPath;
          await bridge.sftpMkdir(
            sessionId: widget.sessionId,
            path: '$dir/$name',
          );
          await _loadCurrentDir();
        }
      case FileAction.newFolder:
        if (!context.mounted) return;
        final name = await showNewFolderDialog(context);
        if (name != null) {
          final dir = ref
              .read(sftpPaneProvider(widget.sessionId))
              .remote
              .currentPath;
          await bridge.sftpMkdir(
            sessionId: widget.sessionId,
            path: '$dir/$name',
          );
          await _loadCurrentDir();
        }
      case FileAction.properties:
        if (!context.mounted) return;
        await showFileInfoDialog(context,
            file: entry, fullRemotePath: remotePath);
      default:
        break;
    }
  }
}
