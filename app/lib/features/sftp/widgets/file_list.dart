/// Scrollable file list for one SFTP pane (local or remote).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/colors.dart';
import 'file_row.dart';

export 'file_row.dart';

/// Context menu action for a file list entry.
enum FileAction {
  download,
  upload,
  rename,
  delete,
  chmod,
  newFile,
  newFolder,
  properties,
}

/// Column header row for the file list.
class FileListHeader extends StatelessWidget {
  const FileListHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundTertiary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 23), // icon placeholder
          Expanded(flex: 5, child: _ColHeader('名称')),
          SizedBox(
              width: 80,
              child: _ColHeader('大小', align: TextAlign.right)),
          SizedBox(width: 8),
          SizedBox(
              width: 100,
              child: _ColHeader('修改时间', align: TextAlign.right)),
          SizedBox(width: 8),
          SizedBox(
              width: 80,
              child: _ColHeader('权限', align: TextAlign.right)),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String label;
  final TextAlign align;

  const _ColHeader(this.label, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        color: TermexColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
      textAlign: align,
    );
  }
}

/// Scrollable list of [FileRow]s with keyboard navigation and multi-select.
class FileList extends StatefulWidget {
  final List<FileRowData> entries;
  final Set<String> selectedNames;
  final bool isLoading;
  final String? errorMessage;

  final ValueChanged<String> onToggleSelect;
  final ValueChanged<FileRowData> onOpen; // navigate or download
  final void Function(FileRowData entry, FileAction action) onAction;

  const FileList({
    super.key,
    required this.entries,
    required this.selectedNames,
    required this.isLoading,
    this.errorMessage,
    required this.onToggleSelect,
    required this.onOpen,
    required this.onAction,
  });

  @override
  State<FileList> createState() => _FileListState();
}

class _FileListState extends State<FileList> {
  int _cursorIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: TermexColors.primary,
          ),
        ),
      );
    }
    if (widget.errorMessage != null) {
      return Center(
        child: Text(
          widget.errorMessage!,
          style: const TextStyle(color: TermexColors.danger, fontSize: 12),
        ),
      );
    }
    if (widget.entries.isEmpty) {
      return const Center(
        child: Text(
          '（空目录）',
          style: TextStyle(color: TermexColors.textMuted, fontSize: 12),
        ),
      );
    }

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKey,
      child: ListView.builder(
        itemCount: widget.entries.length,
        itemExtent: 28,
        itemBuilder: (context, i) {
          final entry = widget.entries[i];
          return FileRow(
            key: ValueKey(entry.name),
            data: entry,
            isSelected: widget.selectedNames.contains(entry.name),
            onTap: () {
              setState(() => _cursorIndex = i);
              widget.onToggleSelect(entry.name);
            },
            onDoubleTap: () => widget.onOpen(entry),
            onSecondaryTap: () => _showContextMenu(context, entry, i),
          );
        },
      ),
    );
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final entries = widget.entries;
    if (entries.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _cursorIndex = (_cursorIndex + 1).clamp(0, entries.length - 1));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _cursorIndex = (_cursorIndex - 1).clamp(0, entries.length - 1));
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onOpen(entries[_cursorIndex]);
    }
  }

  void _showContextMenu(BuildContext context, FileRowData entry, int idx) async {
    setState(() => _cursorIndex = idx);
    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    final result = await showMenu<FileAction>(
      context: context,
      color: TermexColors.backgroundSecondary,
      position: RelativeRect.fromLTRB(
          offset.dx + 40, offset.dy + idx * 28, offset.dx + 200, 0),
      items: [
        if (!entry.isDirectory)
          const PopupMenuItem(value: FileAction.download, child: Text('下载')),
        const PopupMenuItem(value: FileAction.rename, child: Text('重命名')),
        const PopupMenuItem(value: FileAction.delete, child: Text('删除')),
        if (!entry.isDirectory)
          const PopupMenuItem(value: FileAction.chmod, child: Text('修改权限')),
        const PopupMenuItem(value: FileAction.newFile, child: Text('新建文件')),
        const PopupMenuItem(value: FileAction.newFolder, child: Text('新建文件夹')),
        const PopupMenuItem(value: FileAction.properties, child: Text('属性')),
      ],
    );

    if (result != null) widget.onAction(entry, result);
  }
}
