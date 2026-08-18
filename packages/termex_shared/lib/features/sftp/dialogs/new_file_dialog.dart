/// New file / new folder creation dialogs for SFTP.
library;

import 'package:flutter/material.dart';

import '../../../design/colors.dart';
import '../../../l10n/app_localizations.dart';

/// Shows the "New File" dialog. Returns the file name or `null` if cancelled.
Future<String?> showNewFileDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      title: l10n.sftpNewFile,
      hint: l10n.sftpFileNameHint,
      confirmLabel: l10n.sftpCreate,
    ),
  );
}

/// Shows the "New Folder" dialog. Returns the folder name or `null` if cancelled.
Future<String?> showNewFolderDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      title: l10n.sftpNewFolder,
      hint: l10n.sftpFolderNameHint,
      confirmLabel: l10n.sftpCreate,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String confirmLabel;

  const _NameDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
  });

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.sftpRenameEmpty);
      return;
    }
    if (name.contains('/')) {
      setState(() => _error = l10n.sftpRenameSlash);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.backgroundSecondary,
      title: Text(widget.title,
          style: TextStyle(
              color: context.colors.textPrimary, fontSize: 15)),
      content: SizedBox(
        width: 300,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          style: TextStyle(color: context.colors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(color: context.colors.textMuted),
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).sftpCancel),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
