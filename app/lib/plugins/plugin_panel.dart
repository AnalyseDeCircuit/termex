/// Plugin management panel (v0.48 spec §7.1).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'plugin_permission_dialog.dart';
import 'state/plugin_provider.dart';

class PluginPanel extends ConsumerWidget {
  const PluginPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pluginsProvider);
    final notifier = ref.read(pluginsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          developerMode: state.developerMode,
          onToggleDeveloperMode: notifier.setDeveloperMode,
        ),
        const SizedBox(height: 8),
        if (state.plugins.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('未安装任何插件', style: TextStyle(fontSize: 12)),
          )
        else
          ...state.plugins.map(
            (p) => _PluginRow(
              plugin: p,
              onEnable: () => notifier.enable(p.id),
              onDisable: () => notifier.disable(p.id),
              onRemove: () => notifier.remove(p.id),
              onPermissions: () async {
                final decision =
                    await showPluginPermissionDialog(context, p);
                if (decision == PermissionDecision.grant) {
                  for (final perm in p.permissions) {
                    notifier.grantPermission(p.id, perm);
                  }
                }
              },
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final bool developerMode;
  final void Function(bool) onToggleDeveloperMode;

  const _Header(
      {required this.developerMode,
      required this.onToggleDeveloperMode});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('插件',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const Spacer(),
        const Text('开发者模式', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        Switch(
          value: developerMode,
          onChanged: onToggleDeveloperMode,
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: null, // ZIP install handled by platform
          icon: const Icon(Icons.install_desktop, size: 14),
          label:
              const Text('从 .zip 安装', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

class _PluginRow extends StatelessWidget {
  final PluginInfo plugin;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final VoidCallback onRemove;
  final VoidCallback onPermissions;

  const _PluginRow({
    required this.plugin,
    required this.onEnable,
    required this.onDisable,
    required this.onRemove,
    required this.onPermissions,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = plugin.state == PluginState.enabled;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.extension,
                    size: 16,
                    color: enabled ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                Text('${plugin.name}  v${plugin.version}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: enabled,
                  onChanged: (v) => v ? onEnable() : onDisable(),
                ),
              ],
            ),
            if (plugin.author != null)
              Text('作者: ${plugin.author}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(plugin.description,
                style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                    onPressed: onPermissions,
                    child: const Text('权限', style: TextStyle(fontSize: 11))),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: onRemove,
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red),
                    child: const Text('卸载',
                        style: TextStyle(fontSize: 11))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
