/// Scrollable file list for one SFTP pane (local or remote).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../icons/termex_icons.dart';
import '../../../widgets/context_menu.dart';
import 'file_row.dart';

export 'file_row.dart';

/// Sort order for SFTP file lists.
enum SftpSort { nameAsc, nameDesc, sizeDesc, modifiedDesc, typeFirst }

/// Toolbar above [FileListHeader] with show-hidden toggle and sort dropdown.
class SftpFilterBar extends StatelessWidget {
  final bool showHidden;
  final SftpSort sort;
  final VoidCallback onToggleHidden;
  final ValueChanged<SftpSort> onSortChanged;

  const SftpFilterBar({
    super.key,
    required this.showHidden,
    required this.sort,
    required this.onToggleHidden,
    required this.onSortChanged,
  });

  String _label(SftpSort s, AppLocalizations l) => switch (s) {
        SftpSort.nameAsc => l.sftpSortNameAsc,
        SftpSort.nameDesc => l.sftpSortNameDesc,
        SftpSort.sizeDesc => l.sftpSortSizeDesc,
        SftpSort.modifiedDesc => l.sftpSortModifiedDesc,
        SftpSort.typeFirst => l.sftpSortTypeFirst,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          Flexible(
            child: InkWell(
              onTap: onToggleHidden,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      showHidden
                          ? Icons.visibility
                          : Icons.visibility_off_outlined,
                      size: 13,
                      color: showHidden
                          ? context.colors.primary
                          : context.colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    // Ellipsises instead of overflowing once the pane is docked
                    // narrow; the icon alone still conveys the toggle state.
                    Flexible(
                      child: Text(
                        l10n.sftpShowHidden,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11,
                          color: showHidden
                              ? context.colors.primary
                              : context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          PopupMenuButton<SftpSort>(
            tooltip: l10n.sftpSortTooltip,
            initialValue: sort,
            onSelected: onSortChanged,
            itemBuilder: (_) => SftpSort.values
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Icon(
                            s == sort ? Icons.check : Icons.sort,
                            size: 12,
                            color: s == sort
                                ? context.colors.primary
                                : context.colors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(_label(s, l10n),
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ))
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.sort,
                      size: 12, color: context.colors.textSecondary),
                  const SizedBox(width: 4),
                  // Not Flexible: PopupMenuButton gives its child unbounded
                  // width, where a flex child asserts. The label is short and
                  // the toggle on the left absorbs the shrinking instead.
                  Text(
                    _label(sort, l10n),
                    softWrap: false,
                    style: TextStyle(
                        fontSize: 11, color: context.colors.textSecondary),
                  ),
                  Icon(Icons.arrow_drop_down,
                      size: 14, color: context.colors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Context menu action for a file list entry.
enum FileAction {
  download,
  upload,
  /// Open a small remote text file in the inline editor.
  edit,
  rename,
  delete,
  chmod,
  /// Put the entry's full path on the system clipboard.
  copyPath,
  newFile,
  newFolder,
  properties,
}

/// Column header row for the file list.
class FileListHeader extends StatelessWidget {
  const FileListHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: context.colors.backgroundTertiary,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      // Same width-derived column set the rows use, so the two never disagree.
      // The fixed 23 + 80 + 8 + 100 + 8 + 80 this used to draw needed 315px
      // before the name column got anything, which a side-docked pane does not
      // have — hence the ~100px overflow.
      child: LayoutBuilder(
        builder: (_, c) {
          final cols = SftpColumns.forWidth(c.maxWidth);
          return Row(
            children: [
              const SizedBox(width: SftpColumns.iconWidth),
              Expanded(flex: 5, child: _ColHeader(l10n.sftpColName)),
              if (cols.showSize) ...[
                SizedBox(
                    width: SftpColumns.sizeWidth,
                    child:
                        _ColHeader(l10n.sftpColSize, align: TextAlign.right)),
                const SizedBox(width: SftpColumns.gap),
              ],
              if (cols.showModified) ...[
                SizedBox(
                    width: SftpColumns.modifiedWidth,
                    child: _ColHeader(l10n.sftpColModified,
                        align: TextAlign.right)),
                const SizedBox(width: SftpColumns.gap),
              ],
              if (cols.showPermissions)
                SizedBox(
                    width: SftpColumns.permissionsWidth,
                    child: _ColHeader(l10n.sftpColPermissions,
                        align: TextAlign.right)),
            ],
          );
        },
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
      style: TextStyle(
        fontSize: 11,
        color: context.colors.textMuted,
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

  /// Modifier-click: adds/removes one entry from the selection.
  final ValueChanged<String> onToggleSelect;

  /// Plain left click: replaces the selection with this entry. Clicking used
  /// to call [onToggleSelect], which accumulated — so every click added
  /// another row and there was no way to go back to one.
  final ValueChanged<String> onSelectOnly;

  /// Invoked by the context menu's "select all".
  final VoidCallback onSelectAll;

  /// Invoked by the context menu's "refresh".
  final VoidCallback onRefresh;
  final ValueChanged<FileRowData> onOpen; // navigate or download
  final void Function(FileRowData entry, FileAction action) onAction;

  /// Optional per-row wrapper, used by the SFTP panes to make each row
  /// draggable across to the other pane. Kept as a hook rather than
  /// baking `Draggable` in here so plain listings (and tests) stay free
  /// of drag machinery. `FileList` still owns loading/error/empty
  /// states, keyboard navigation, column layout and the context menu —
  /// the wrapper only decorates the finished row widget.
  final Widget Function(FileRowData entry, Widget row)? rowWrapper;

  const FileList({
    super.key,
    required this.entries,
    required this.selectedNames,
    required this.isLoading,
    this.errorMessage,
    required this.onToggleSelect,
    required this.onSelectOnly,
    required this.onSelectAll,
    required this.onRefresh,
    required this.onOpen,
    required this.onAction,
    this.rowWrapper,
  });

  @override
  State<FileList> createState() => _FileListState();
}

class _FileListState extends State<FileList> {
  int _cursorIndex = 0;

  @override
  void dispose() {
    // The menu lives in the Overlay, not this subtree, so it outlives the
    // list unless removed explicitly.
    _closeMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.colors.primary,
          ),
        ),
      );
    }
    if (widget.errorMessage != null) {
      return Center(
        child: Text(
          widget.errorMessage!,
          style: TextStyle(color: context.colors.danger, fontSize: 12),
        ),
      );
    }
    if (widget.entries.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).sftpEmptyDir,
          style: TextStyle(color: context.colors.textMuted, fontSize: 12),
        ),
      );
    }

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKey,
      // Resolved once for the whole list rather than per row: every row must
      // agree with FileListHeader, and a LayoutBuilder per row would re-measure
      // on every scroll.
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = SftpColumns.forWidth(c.maxWidth - 16);
          return ListView.builder(
            itemCount: widget.entries.length,
            itemExtent: 28,
            itemBuilder: (context, i) {
              final entry = widget.entries[i];
              final row = FileRow(
                key: ValueKey(entry.name),
                columns: cols,
                data: entry,
                isSelected: widget.selectedNames.contains(entry.name),
                onTap: () {
                  setState(() => _cursorIndex = i);
                  // Plain click replaces the selection; only a modifier-click
                  // accumulates. It used to always toggle, so every click
                  // added another row with no way back to a single one.
                  final multi = HardwareKeyboard.instance.isMetaPressed ||
                      HardwareKeyboard.instance.isControlPressed;
                  if (multi) {
                    widget.onToggleSelect(entry.name);
                  } else {
                    widget.onSelectOnly(entry.name);
                  }
                },
                onDoubleTap: () => widget.onOpen(entry),
                onSecondaryTap: (pos) => _showContextMenu(entry, i, pos),
              );
              return widget.rowWrapper?.call(entry, row) ?? row;
            },
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
      setState(
          () => _cursorIndex = (_cursorIndex + 1).clamp(0, entries.length - 1));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(
          () => _cursorIndex = (_cursorIndex - 1).clamp(0, entries.length - 1));
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onOpen(entries[_cursorIndex]);
    }
  }

  OverlayEntry? _menuEntry;

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _showContextMenu(FileRowData entry, int idx, Offset globalPos) {
    _closeMenu();
    setState(() => _cursorIndex = idx);

    // Right-clicking an unselected row selects it first, so the action always
    // applies to what the user pointed at.
    if (!widget.selectedNames.contains(entry.name)) {
      widget.onSelectOnly(entry.name);
    }

    final l10n = AppLocalizations.of(context);
    void act(FileAction a) => widget.onAction(entry, a);

    // Same component the sidebar uses. Material's showMenu enforces a 48px
    // minimum row, which looked padded next to the dense file rows while its
    // intrinsic width still clipped the longer labels.
    // Ordering follows the Tauri pane (src/components/sftp/RemoteFilePane.vue).
    final items = <TermexMenuItem>[
      if (!entry.isDirectory)
        TermexMenuItem(
          icon: TermexIcons.download,
          label: l10n.sftpActionDownload,
          onSelect: () => act(FileAction.download),
        ),
      if (!entry.isDirectory)
        TermexMenuItem(
          icon: TermexIcons.edit,
          label: l10n.sftpActionEdit,
          onSelect: () => act(FileAction.edit),
        ),
      TermexMenuItem(
        divided: !entry.isDirectory,
        icon: TermexIcons.edit,
        label: l10n.sftpActionRename,
        onSelect: () => act(FileAction.rename),
      ),
      TermexMenuItem(
        icon: TermexIcons.copy,
        label: l10n.sftpActionCopyPath,
        onSelect: () => act(FileAction.copyPath),
      ),
      if (!entry.isDirectory)
        TermexMenuItem(
          icon: TermexIcons.lock,
          label: l10n.sftpActionChmod,
          onSelect: () => act(FileAction.chmod),
        ),
      TermexMenuItem(
        divided: true,
        icon: TermexIcons.file,
        label: l10n.sftpActionNewFile,
        onSelect: () => act(FileAction.newFile),
      ),
      TermexMenuItem(
        icon: TermexIcons.folder,
        label: l10n.sftpActionNewFolder,
        onSelect: () => act(FileAction.newFolder),
      ),
      // List-level concerns the pane exposes directly rather than via onAction.
      TermexMenuItem(
        divided: true,
        icon: TermexIcons.check,
        label: l10n.sftpActionSelectAll,
        onSelect: widget.onSelectAll,
      ),
      TermexMenuItem(
        icon: TermexIcons.refresh,
        label: l10n.commonRefresh,
        onSelect: widget.onRefresh,
      ),
      TermexMenuItem(
        divided: true,
        icon: TermexIcons.info,
        label: l10n.sftpActionProperties,
        onSelect: () => act(FileAction.properties),
      ),
      TermexMenuItem(
        divided: true,
        danger: true,
        icon: TermexIcons.delete,
        label: l10n.sftpActionDelete,
        onSelect: () => act(FileAction.delete),
      ),
    ];

    _menuEntry = OverlayEntry(
      builder: (_) => TermexContextMenu(
        position: globalPos,
        screenSize: MediaQuery.sizeOf(context),
        items: items,
        width: 200,
        onDismiss: _closeMenu,
      ),
    );
    Overlay.of(context).insert(_menuEntry!);
  }
}
