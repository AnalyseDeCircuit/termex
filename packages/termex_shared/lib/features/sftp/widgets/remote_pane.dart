/// Remote filesystem pane for the SFTP dual-pane browser.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/src/api.dart' as bridge;

import '../../../l10n/app_localizations.dart';
import '../../../widgets/toast.dart';
import '../dialogs/chmod_dialog.dart';
import '../dialogs/file_info_dialog.dart';
import '../dialogs/new_file_dialog.dart';
import '../dialogs/rename_dialog.dart';
import '../state/sftp_pane_provider.dart';
import '../state/sftp_session_provider.dart';
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
    // Deferred for the same reason as LocalPane: `_loadCurrentDir` calls
    // `setRemoteLoading(true)` first, and mutating a provider during the
    // build phase throws — leaving the spinner on with no request in
    // flight and no timeout armed. See the comment in local_pane.dart.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCurrentDir();
    });
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
    var path = ref.read(sftpPaneProvider(widget.sessionId)).remote.currentPath;

    // The pane's initial remote path is the literal placeholder `~`, but SFTP
    // does no shell expansion — `~` is just a directory name to the server, so
    // listing it fails with "no such file". `sftpSessionProvider.open()` has
    // already canonicalised `.` into the real home (e.g. /home/huzou); adopt
    // that here instead of sending the placeholder over the wire.
    if (path == '~') {
      final resolved =
          ref.read(sftpSessionProvider(widget.sessionId)).remoteCwd;
      if (resolved.isNotEmpty && resolved != '~') {
        path = resolved;
        notifier.navigateRemote(resolved);
      }
    }

    notifier.setRemoteLoading(true);
    notifier.setRemoteError(null);
    try {
      // Bounded so a request that never comes back shows a reason instead of
      // an endless spinner. The pane had no timeout at all, which is why a
      // stalled listing was indistinguishable from a slow one.
      final entries = await bridge
          .sftpList(sessionId: widget.sessionId, path: path)
          .timeout(const Duration(seconds: 20),
              onTimeout: () => throw TimeoutException(
                  'sftpList("$path") did not return within 20s'));
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
        // The DTO carries owner/group as the numeric uid/gid rendered as
        // strings (bridge maps e.uid/e.gid via to_string), so they parse
        // back to ints for pre-filling the chown fields.
        final result = await showChmodDialog(
          context,
          fileName: entry.name,
          initialPermissions:
              entry.permissions?.replaceAll(RegExp(r'\D'), '') ?? '644',
          initialUid: int.tryParse(entry.owner ?? ''),
          initialGid: int.tryParse(entry.group ?? ''),
        );
        if (result != null) {
          try {
            await bridge.sftpChmod(
              sessionId: widget.sessionId,
              path: remotePath,
              mode: int.parse(result.mode, radix: 8),
            );
            // chown only when the user actually changed owner/group.
            if (result.uid != null && result.gid != null) {
              await bridge.sftpChown(
                sessionId: widget.sessionId,
                path: remotePath,
                uid: result.uid!,
                gid: result.gid!,
              );
            }
            await _loadCurrentDir();
          } catch (e) {
            if (context.mounted) {
              ToastController.error(
                  AppLocalizations.of(context).sftpChmodApplyFailed('$e'));
            }
          }
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
