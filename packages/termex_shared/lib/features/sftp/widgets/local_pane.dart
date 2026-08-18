/// Local filesystem pane for the SFTP dual-pane browser.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/api.dart' as bridge;

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
    // Deferred to the first post-frame callback: `_loadCurrentDir` starts by
    // calling `setLocalLoading(true)`, and mutating a provider while the
    // widget tree is still building throws
    // "tried to modify a provider while the widget tree was building".
    // That exception aborted `_loadCurrentDir` *after* the spinner was
    // switched on but *before* `localListDir` was ever called — so the
    // request was never sent, the 20s timeout never armed, and the `finally`
    // that clears the spinner never ran. The pane span forever.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openHomeThenLoad();
    });
  }

  /// Resolves the real home directory before the first listing.
  ///
  /// `SftpPaneNotifier._homeDir()` returns the literal `'/'` as a placeholder,
  /// with a comment saying LocalPane would call `navigateLocal` after boot —
  /// which never happened, so the pane opened on the filesystem root and
  /// stayed there. That was not just cosmetic: the drop handler builds the
  /// destination from the opposite pane's `currentPath`, so every download
  /// targeted `/<name>` and failed with "Read-only file system (os error 30)"
  /// on macOS, and dragging out of `/` picked up unreadable system entries
  /// like `/.file` ("Permission denied (os error 13)").
  Future<void> _openHomeThenLoad() async {
    final pane = ref.read(sftpPaneProvider(widget.sessionId));
    if (pane.local.currentPath == '/') {
      try {
        final home = await bridge.localHomeDir();
        if (!mounted) return;
        if (home.isNotEmpty && home != '/') {
          ref
              .read(sftpPaneProvider(widget.sessionId).notifier)
              .navigateLocal(home);
        }
      } catch (_) {
        // Home is unresolvable (headless container, odd HOME) — fall back to
        // listing `/` rather than leaving the pane blank.
      }
    }
    if (mounted) await _loadCurrentDir();
  }

  Future<void> _loadCurrentDir() async {
    final notifier = ref.read(sftpPaneProvider(widget.sessionId).notifier);
    final currentPath = ref
        .read(sftpPaneProvider(widget.sessionId))
        .local
        .currentPath;
    notifier.setLocalLoading(true);
    try {
      final entries = await bridge
          .localListDir(path: currentPath)
          .timeout(const Duration(seconds: 20),
              onTimeout: () => throw TimeoutException(
                  'localListDir("$currentPath") did not return within 20s'));
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
                  permissions: e.permissions?.toRadixString(8),
                ))
            .toList();
      });
    } catch (e) {
      // Previously swallowed, so a failure looked exactly like an empty
      // directory and gave the user nothing to report.
      notifier.setLocalError(e.toString());
      if (mounted) setState(() => _entries = []);
    } finally {
      notifier.setLocalLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reload once a transfer that wrote into this pane finishes. Nothing
    // watched completion before, so an uploaded/downloaded file only appeared
    // after a manual refresh or a directory change.
    ref.listen<SftpTransferState>(
      sftpTransferProvider(widget.sessionId),
      (prev, next) {
        final before = prev?.items
                .where((t) => t.status == TransferStatus.completed)
                .length ??
            0;
        final after = next.items
            .where((t) => t.status == TransferStatus.completed)
            .length;
        if (after <= before) return;
        final landedHere = next.items.any((t) =>
            t.status == TransferStatus.completed &&
            t.direction == TransferDirection.download);
        if (landedHere) _loadCurrentDir();
      },
    );

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
            child: FileList(
              entries: _entries,
              selectedNames: local.selectedNames,
              isLoading: local.isLoading,
              errorMessage: local.errorMessage,
              // Only files are draggable: the transfer queue has no
              // recursive directory walk, so a dragged folder would
              // enqueue a transfer that cannot complete. Matches the
              // double-tap rule, which also only downloads files.
              rowWrapper: (entry, row) => entry.isDirectory
                  ? row
                  : wrapRowDraggable(
                      entry: entry,
                      row: row,
                      side: DragSide.local,
                      absolutePath:
                          sftpJoin(local.currentPath, entry.name),
                    ),
              onToggleSelect: (name) => ref
                  .read(sftpPaneProvider(widget.sessionId).notifier)
                  .toggleLocalSelection(name),
              onSelectOnly: (name) => ref
                  .read(sftpPaneProvider(widget.sessionId).notifier)
                  .selectLocalOnly(name),
              onSelectAll: () => ref
                  .read(sftpPaneProvider(widget.sessionId).notifier)
                  .selectAllLocal(_entries.map((e) => e.name)),
              onRefresh: _loadCurrentDir,
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
