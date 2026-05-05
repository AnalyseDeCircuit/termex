/// File properties / info dialog for SFTP.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../widgets/file_row.dart';

/// Shows the file properties dialog. Returns when the user closes it.
Future<void> showFileInfoDialog(
  BuildContext context, {
  required FileRowData file,
  required String fullRemotePath,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        FileInfoDialog(file: file, fullRemotePath: fullRemotePath),
  );
}

class FileInfoDialog extends StatelessWidget {
  final FileRowData file;
  final String fullRemotePath;

  const FileInfoDialog({
    super.key,
    required this.file,
    required this.fullRemotePath,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TermexColors.backgroundSecondary,
      title: Row(
        children: [
          Icon(
            file.isDirectory ? Icons.folder : Icons.insert_drive_file_outlined,
            color: file.isDirectory
                ? TermexColors.warning
                : TermexColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              file.name,
              style: const TextStyle(
                  color: TermexColors.textPrimary, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow(label: '类型', value: file.isDirectory ? '目录' : '文件'),
            _InfoRow(label: '路径', value: fullRemotePath, copyable: true),
            if (file.sizeBytes != null)
              _InfoRow(label: '大小', value: _formatSize(file.sizeBytes!)),
            if (file.modifiedAt != null)
              _InfoRow(
                label: '修改时间',
                value: file.modifiedAt!.toLocal().toString(),
              ),
            if (file.permissions != null)
              _InfoRow(label: '权限', value: file.permissions!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes 字节';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB ($bytes 字节)';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB ($bytes 字节)';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(3)} GB ($bytes 字节)';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;

  const _InfoRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12, color: TermexColors.textMuted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TermexTypography.monospace.copyWith(
                fontSize: 12,
                color: TermexColors.textPrimary,
              ),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () => Clipboard.setData(ClipboardData(text: value)),
              child: const Icon(Icons.copy_outlined,
                  size: 13, color: TermexColors.textMuted),
            ),
        ],
      ),
    );
  }
}
