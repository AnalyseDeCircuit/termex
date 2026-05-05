/// Backup / export / import settings tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../state/settings_provider.dart';
import '../widgets/setting_row.dart';

class BackupTab extends ConsumerWidget {
  const BackupTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).settings;
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SettingRow(
          label: '自动备份频率',
          hint: '.termex 加密备份的自动生成周期',
          child: DropdownButton<BackupFrequency>(
            value: settings.backupFrequency,
            dropdownColor: TermexColors.backgroundSecondary,
            items: const [
              DropdownMenuItem(value: BackupFrequency.off, child: Text('关闭')),
              DropdownMenuItem(value: BackupFrequency.daily, child: Text('每日')),
              DropdownMenuItem(value: BackupFrequency.weekly, child: Text('每周')),
            ],
            onChanged: (v) =>
                notifier.update(settings.copyWith(backupFrequency: v!)),
            style: TextStyle(fontSize: 12, color: TermexColors.textPrimary),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '.termex 备份文件使用 AES-256-GCM + Argon2id 加密。',
          style: TextStyle(fontSize: 11, color: TermexColors.textSecondary),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _exportWithPassword(context, notifier),
          icon: const Icon(Icons.upload_file, size: 14),
          label: const Text('导出配置 (.termex)', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: TermexColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _importWithPassword(context, notifier),
          icon: const Icon(Icons.download_rounded, size: 14),
          label: const Text('导入配置', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: TermexColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _exportWithPassword(
      BuildContext context, SettingsNotifier notifier) async {
    // Password-protected export flow placeholder — full file-picker
    // integration lands alongside platform-specific file dialogs.
    final password = await _promptPassword(context, '输入加密密码');
    if (password == null || password.isEmpty) return;
    await notifier.exportConfig('termex-backup.termex', password);
  }

  Future<void> _importWithPassword(
      BuildContext context, SettingsNotifier notifier) async {
    final password = await _promptPassword(context, '输入解密密码');
    if (password == null || password.isEmpty) return;
    await notifier.importConfig('termex-backup.termex', password);
  }

  Future<String?> _promptPassword(BuildContext context, String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: '密码（至少 12 位）'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
