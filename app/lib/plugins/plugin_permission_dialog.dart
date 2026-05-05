/// Plugin permission request dialog (v0.48 spec §7.2).
library;

import 'package:flutter/material.dart';

import 'state/plugin_provider.dart';

enum PermissionDecision { deny, grantOnce, grant }

Future<PermissionDecision?> showPluginPermissionDialog(
  BuildContext context,
  PluginInfo plugin,
) {
  return showDialog<PermissionDecision>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('插件权限请求'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${plugin.name} v${plugin.version} 请求以下权限：',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...plugin.permissions.map((perm) {
              final isGranted = plugin.grantedPermissions.contains(perm);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      isGranted ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: isGranted ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _permissionLabel(perm),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, PermissionDecision.deny),
          child: const Text('拒绝'),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(ctx, PermissionDecision.grantOnce),
          child: const Text('仅本次'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, PermissionDecision.grant),
          child: const Text('授予'),
        ),
      ],
    ),
  );
}

String _permissionLabel(String permission) {
  const labels = {
    'terminal_read': '读取终端输出',
    'terminal_write': '写入终端输入',
    'server_info': '访问服务器连接信息',
    'network': '访问网络',
    'storage': '读写插件存储',
    'clipboard': '访问剪贴板',
    'notification': '显示通知',
  };
  return labels[permission] ?? permission;
}
