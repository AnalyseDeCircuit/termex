/// AWS SSM start-session confirmation dialog.
library;

import 'package:flutter/material.dart';

import '../state/cloud_provider.dart';

Future<bool> showSsmSessionDialog({
  required BuildContext context,
  required SsmInstance instance,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('启动 SSM Session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('实例 ID：${instance.instanceId}'),
          Text('名称：${instance.name}'),
          Text('区域：${instance.region}'),
          const SizedBox(height: 12),
          const Text('将通过 AWS Systems Manager 启动 session 并桥接终端。',
              style: TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('开始'),
        ),
      ],
    ),
  );
  return result ?? false;
}
