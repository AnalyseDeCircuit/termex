import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../widgets/bottom_sheet.dart';
import '../../widgets/list_item.dart';
import 'widgets/file_row.dart';

/// Bottom sheet with contextual actions for a long-pressed SFTP file/directory.
///
/// Returns the chosen [FileAction] (or `null` if dismissed).
enum FileAction { download, rename, chmod, delete, copyPath }

Future<FileAction?> showFileActionsSheet({
  required BuildContext context,
  required FileRowData file,
}) =>
    showTermexBottomSheet<FileAction>(
      context: context,
      child: _FileActionsSheetContent(file: file),
    );

class _FileActionsSheetContent extends StatelessWidget {
  final FileRowData file;

  const _FileActionsSheetContent({required this.file});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final actions = _buildActions(context, colors);

    return Padding(
      padding: const EdgeInsets.only(
        left: TermexSpacing.md,
        right: TermexSpacing.md,
        bottom: TermexSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TermexSpacing.md),
            child: Row(
              children: [
                Icon(
                  file.isDirectory
                      ? const IconData(0xe2c7, fontFamily: 'MaterialIcons')
                      : const IconData(0xe873, fontFamily: 'MaterialIcons'),
                  size: 18,
                  color: file.isDirectory
                      ? colors.warning
                      : colors.textSecondary,
                ),
                const SizedBox(width: TermexSpacing.sm),
                Expanded(
                  child: Text(
                    file.name,
                    style: TermexTypography.body.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, TermexColorScheme colors) {
    final all = <(FileAction, String, IconData)>[
      if (!file.isDirectory)
        (FileAction.download, '下载', const IconData(0xe2c4, fontFamily: 'MaterialIcons')),
      (FileAction.rename, '重命名', const IconData(0xe3c9, fontFamily: 'MaterialIcons')),
      (FileAction.chmod, '修改权限', const IconData(0xe897, fontFamily: 'MaterialIcons')),
      (FileAction.copyPath, '复制路径', const IconData(0xe14d, fontFamily: 'MaterialIcons')),
      (FileAction.delete, '删除', const IconData(0xe872, fontFamily: 'MaterialIcons')),
    ];

    return all.map((entry) {
      final (action, label, icon) = entry;
      final isDanger = action == FileAction.delete;
      return TermexListItem(
        leading: Icon(
          icon,
          size: 18,
          color: isDanger ? colors.danger : colors.textSecondary,
        ),
        title: label,
        onTap: () => Navigator.of(context, rootNavigator: true).pop(action),
      );
    }).toList();
  }
}

/// Helper widget: copy-path action that uses [Clipboard].
///
/// Call directly when [FileAction.copyPath] is returned from the sheet.
void copyPathToClipboard(BuildContext context, String path) {
  Clipboard.setData(ClipboardData(text: path));
}
