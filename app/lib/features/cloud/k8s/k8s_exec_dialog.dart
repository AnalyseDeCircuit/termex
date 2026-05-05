/// K8s pod exec shell dialog — pick container + start shell session.
library;

import 'package:flutter/material.dart';

Future<String?> showK8sExecDialog({
  required BuildContext context,
  required String podName,
  required List<String> containers,
}) {
  String selected = containers.isNotEmpty ? containers.first : '';
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Exec Shell — $podName'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('选择容器：', style: Theme.of(ctx).textTheme.bodyMedium),
          const SizedBox(height: 12),
          DropdownButton<String>(
            value: selected,
            isExpanded: true,
            items: containers
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v != null) selected = v;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, selected),
          child: const Text('启动 Shell'),
        ),
      ],
    ),
  );
}
