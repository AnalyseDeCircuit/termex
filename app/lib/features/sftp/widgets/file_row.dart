/// A single file/directory row in the SFTP file browser.
library;

import 'package:flutter/material.dart';

import '../../../design/colors.dart';
import '../../../design/typography.dart';

/// Data required to render one file row.
class FileRowData {
  final String name;
  final bool isDirectory;
  final int? sizeBytes;
  final DateTime? modifiedAt;
  final String? permissions;

  const FileRowData({
    required this.name,
    required this.isDirectory,
    this.sizeBytes,
    this.modifiedAt,
    this.permissions,
  });
}

/// A tappable row representing one filesystem entry.
///
/// [isSelected] highlights the row with the primary accent color.
/// [onDoubleTap] navigates into directories or triggers download for files.
class FileRow extends StatelessWidget {
  final FileRowData data;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onSecondaryTap;

  const FileRow({
    super.key,
    required this.data,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onSecondaryTap: onSecondaryTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: isSelected
            ? TermexColors.primary.withOpacity(0.2)
            : Colors.transparent,
        child: Row(
          children: [
            // File type icon
            Icon(
              data.isDirectory ? Icons.folder : _fileIcon(data.name),
              size: 15,
              color: data.isDirectory
                  ? TermexColors.warning
                  : TermexColors.textSecondary,
            ),
            const SizedBox(width: 8),
            // Name
            Expanded(
              flex: 5,
              child: Text(
                data.name,
                style: TermexTypography.monospace.copyWith(
                  fontSize: 13,
                  color: isSelected
                      ? TermexColors.textPrimary
                      : TermexColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Size
            SizedBox(
              width: 72,
              child: Text(
                data.isDirectory ? '' : _formatSize(data.sizeBytes),
                style: const TextStyle(
                  fontSize: 11,
                  color: TermexColors.textMuted,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            // Modified date
            SizedBox(
              width: 100,
              child: Text(
                _formatDate(data.modifiedAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: TermexColors.textMuted,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            // Permissions
            SizedBox(
              width: 80,
              child: Text(
                data.permissions ?? '',
                style: TermexTypography.monospace.copyWith(
                  fontSize: 10,
                  color: TermexColors.textMuted,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'dart' || 'rs' || 'py' || 'js' || 'ts' || 'go' || 'rb' || 'java' ||
          'c' || 'cpp' || 'h' =>
        Icons.code,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'svg' || 'webp' =>
        Icons.image_outlined,
      'mp4' || 'mkv' || 'avi' || 'mov' => Icons.movie_outlined,
      'mp3' || 'wav' || 'flac' => Icons.audio_file_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      'zip' || 'tar' || 'gz' || 'bz2' || '7z' => Icons.archive_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  static String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year) {
      return '${_pad(dt.month)}-${_pad(dt.day)} ${_pad(dt.hour)}:${_pad(dt.minute)}';
    }
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
