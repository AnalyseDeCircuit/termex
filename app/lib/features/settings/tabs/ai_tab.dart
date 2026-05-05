/// AI assistant settings tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../ai/provider/provider_config_dialog.dart';
import '../../ai/state/provider_config_provider.dart';
import '../state/settings_provider.dart';
import '../widgets/setting_row.dart';

class AiTab extends ConsumerWidget {
  const AiTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(providerConfigProvider).activeConfig;
    final settings = ref.watch(settingsProvider).settings;
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SettingRow(
          label: '默认上下文行数',
          hint: '发送给 AI 的终端历史行数上限',
          child: DropdownButton<int>(
            value: settings.aiContextLines,
            dropdownColor: TermexColors.backgroundSecondary,
            items: const [
              DropdownMenuItem(value: 50, child: Text('50 行')),
              DropdownMenuItem(value: 100, child: Text('100 行')),
              DropdownMenuItem(value: 200, child: Text('200 行')),
              DropdownMenuItem(value: 500, child: Text('500 行')),
            ],
            onChanged: (v) =>
                notifier.update(settings.copyWith(aiContextLines: v!)),
            style: TextStyle(fontSize: 12, color: TermexColors.textPrimary),
          ),
        ),
        SettingRow(
          label: '自动错误诊断',
          hint: '命令失败时自动触发 AI 分析',
          child: Switch(
            value: settings.aiAutoDiagnose,
            onChanged: (v) =>
                notifier.update(settings.copyWith(aiAutoDiagnose: v)),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
            onPressed: () => showProviderConfigDialog(context, config.provider),
            style: ElevatedButton.styleFrom(
              backgroundColor: TermexColors.backgroundTertiary,
              foregroundColor: TermexColors.textPrimary,
            ),
            child: const Text('配置 AI Provider'),
          ),
        ),
      ],
    );
  }
}
