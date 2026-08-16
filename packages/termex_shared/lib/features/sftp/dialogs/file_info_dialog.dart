/// File properties / info dialog for SFTP.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/colors.dart';
import '../../../design/typography.dart';
import '../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
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
            _InfoRow(
              label: l10n.sftpType,
              value: file.isDirectory ? l10n.sftpDirectory : l10n.sftpFile,
            ),
            _InfoRow(label: l10n.sftpPath, value: fullRemotePath, copyable: true),
            if (file.sizeBytes != null)
              _InfoRow(
                label: l10n.sftpSize,
                value: _formatSize(l10n, file.sizeBytes!),
              ),
            if (file.modifiedAt != null)
              _InfoRow(
                label: l10n.sftpModified,
                value: file.modifiedAt!.toLocal().toString(),
              ),
            if (file.permissions != null)
              _InfoRow(label: l10n.sftpPermissions, value: file.permissions!),
            if (file.owner != null)
              _InfoRow(label: l10n.sftpOwner, value: file.owner!),
            if (file.group != null)
              _InfoRow(label: l10n.sftpGroup, value: file.group!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.sftpClose),
        ),
      ],
    );
  }

  static String _formatSize(AppLocalizations l10n, int bytes) {
    if (bytes < 1024) return l10n.sftpSizeBytes(bytes);
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB (${l10n.sftpSizeBytes(bytes)})';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB (${l10n.sftpSizeBytes(bytes)})';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(3)} GB (${l10n.sftpSizeBytes(bytes)})';
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
