/// Git Sync conflict resolver dialog (v0.47 spec §7.3).
library;

import 'package:flutter/material.dart';

enum ConflictResolution { keepLocal, useRemote, terminalMergeTool }

Future<ConflictResolution?> showConflictResolver(
  BuildContext context,
  List<String> conflicts,
) {
  return showDialog<ConflictResolution>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('⚠ Git Sync 冲突'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('以下文件存在冲突：', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: conflicts.length,
                itemBuilder: (ctx, i) => Text('  • ${conflicts[i]}',
                    style: const TextStyle(
                        fontSize: 11, fontFamily: 'monospace')),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '选择解决策略：',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(ctx, ConflictResolution.terminalMergeTool),
          child: const Text('终端中解决'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, ConflictResolution.useRemote),
          child: const Text('使用远端'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, ConflictResolution.keepLocal),
          child: const Text('保留本地'),
        ),
      ],
    ),
  );
}
