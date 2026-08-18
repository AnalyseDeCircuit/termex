/// Inline file editor for small remote text files.
///
/// Guards:
///   - Rejects files larger than 1 MiB.
///   - Rejects binary content (any null byte in the first 1 KiB).
///
/// On save, writes the edited content back to the server via
/// [bridge.sftpWriteFileBytes] and refreshes the parent listing.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:termex_bridge/api.dart' as bridge;

import '../../../design/colors.dart';
import '../../../l10n/app_localizations.dart';

const int _maxBytes = 1024 * 1024; // 1 MiB
const int _binaryProbeBytes = 1024;

/// Opens the file editor dialog. Callers should await to know when it closes.
Future<void> showFileEditorDialog(
  BuildContext context, {
  required String sessionId,
  required String remotePath,
  required int fileSize,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FileEditorDialog(
      sessionId: sessionId,
      remotePath: remotePath,
      fileSize: fileSize,
    ),
  );
}

class _FileEditorDialog extends StatefulWidget {
  final String sessionId;
  final String remotePath;
  final int fileSize;

  const _FileEditorDialog({
    required this.sessionId,
    required this.remotePath,
    required this.fileSize,
  });

  @override
  State<_FileEditorDialog> createState() => _FileEditorDialogState();
}

class _FileEditorDialogState extends State<_FileEditorDialog> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _modified = false;
  String? _errorMessage;
  final String _encoding = 'UTF-8';

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    final l10n = AppLocalizations.of(context);
    if (widget.fileSize > _maxBytes) {
      setState(() {
        _loading = false;
        _errorMessage = l10n.sftpEditorTooLarge(_formatSize(widget.fileSize));
      });
      return;
    }
    try {
      final bytes = await bridge.sftpReadFileBytes(
        sessionId: widget.sessionId,
        path: widget.remotePath,
        maxBytes: _maxBytes,
      );
      // Binary detection: any null byte in the first probe window.
      final probe = bytes.length > _binaryProbeBytes
          ? bytes.sublist(0, _binaryProbeBytes)
          : bytes;
      if (probe.contains(0)) {
        setState(() {
          _loading = false;
          _errorMessage = l10n.sftpEditorBinary;
        });
        return;
      }
      final text = utf8.decode(bytes, allowMalformed: false);
      _controller.text = text;
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = l10n.sftpEditorReadFailed(e.toString());
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final bytes = utf8.encode(_controller.text);
      await bridge.sftpWriteFileBytes(
        sessionId: widget.sessionId,
        path: widget.remotePath,
        data: bytes,
      );
      setState(() {
        _saving = false;
        _modified = false;
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = l10n.sftpEditorSaveFailed(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.remotePath.split('/').last;

    return Dialog(
      backgroundColor: context.colors.backgroundSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitleBar(fileName),
            Divider(height: 1, color: context.colors.border),
            Expanded(child: _buildBody()),
            Divider(height: 1, color: context.colors.border),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar(String fileName) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 16, color: context.colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_modified)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                l10n.sftpEditorModified,
                style: TextStyle(
                    color: context.colors.warning, fontSize: 11),
              ),
            ),
          Text(
            _encoding,
            style: TextStyle(color: context.colors.textMuted, fontSize: 11),
          ),
          const SizedBox(width: 12),
          Text(
            _formatSize(widget.fileSize),
            style: TextStyle(color: context.colors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: context.colors.primary),
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  color: context.colors.danger, size: 32),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return TextField(
      controller: _controller,
      maxLines: null,
      expands: true,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: context.colors.textPrimary,
        height: 1.5,
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.all(12),
        border: InputBorder.none,
        fillColor: context.colors.backgroundPrimary,
        filled: true,
      ),
      onChanged: (_) {
        if (!_modified) setState(() => _modified = true);
      },
    );
  }

  Widget _buildFooter() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.sftpCancel,
                style: TextStyle(color: context.colors.textMuted)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _loading || _errorMessage != null || _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.colors.primary),
                  )
                : Text(l10n.commonSave,
                    style: TextStyle(color: context.colors.primary)),
          ),
        ],
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
