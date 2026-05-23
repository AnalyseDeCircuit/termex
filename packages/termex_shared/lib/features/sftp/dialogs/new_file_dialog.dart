/// New file / new folder creation dialogs for SFTP.
library;

import 'package:flutter/material.dart';

import '../../../design/colors.dart';

/// Shows the "New File" dialog. Returns the file name or `null` if cancelled.
Future<String?> showNewFileDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _NameDialog(
      title: '新建文件',
      hint: '文件名',
      confirmLabel: '创建',
    ),
  );
}

/// Shows the "New Folder" dialog. Returns the folder name or `null` if cancelled.
Future<String?> showNewFolderDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _NameDialog(
      title: '新建文件夹',
      hint: '文件夹名',
      confirmLabel: '创建',
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
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '名称不能为空');
      return;
    }
    if (name.contains('/')) {
      setState(() => _error = '名称不能包含 /');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TermexColors.backgroundSecondary,
      title: Text(widget.title,
          style: const TextStyle(
              color: TermexColors.textPrimary, fontSize: 15)),
      content: SizedBox(
        width: 300,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: TermexColors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: TermexColors.textMuted),
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
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
