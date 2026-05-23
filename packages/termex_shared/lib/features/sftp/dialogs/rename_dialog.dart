/// Rename file/directory dialog for SFTP.
library;

import 'package:flutter/material.dart';

import '../../../design/colors.dart';

/// Shows a rename dialog and returns the new name, or `null` if cancelled.
Future<String?> showRenameDialog(
  BuildContext context, {
  required String currentName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => RenameDialog(currentName: currentName),
  );
}

class RenameDialog extends StatefulWidget {
  final String currentName;

  const RenameDialog({super.key, required this.currentName});

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentName);
    // Pre-select the name without extension for files.
    final dot = widget.currentName.lastIndexOf('.');
    if (dot > 0) {
      _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: dot);
    } else {
      _ctrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.currentName.length,
      );
    }
  }

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
      title: const Text('重命名',
          style: TextStyle(color: TermexColors.textPrimary, fontSize: 15)),
      content: SizedBox(
        width: 300,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: TermexColors.textPrimary),
          decoration: InputDecoration(
            hintText: '新名称',
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
          child: const Text('重命名'),
        ),
      ],
    );
  }
}
