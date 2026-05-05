import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens.dart';
import '../state/settings_provider.dart';

class PrivacyTab extends ConsumerWidget {
  const PrivacyTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _DangerSection(
          title: '清除历史数据',
          children: [
            _ClearButton(
              label: '清除最近连接历史',
              onTap: () => notifier.clearConnectionHistory(),
            ),
            _ClearButton(
              label: '清除 AI 对话历史',
              onTap: () => notifier.clearAiConversations(),
            ),
            _ClearButton(
              label: '清除 Snippet 使用统计',
              onTap: () => notifier.clearSnippetStats(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _DangerSection(
          title: 'GDPR 数据擦除',
          danger: true,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '永久删除所有本地数据（服务器配置、凭据、对话、设置）。此操作不可恢复。',
                style: TextStyle(fontSize: 12, color: TermexColors.textSecondary),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showGdprDialog(context, notifier),
              icon: const Icon(Icons.delete_forever, size: 16),
              label: const Text('擦除所有数据'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TermexColors.danger,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showGdprDialog(
      BuildContext context, SettingsNotifier notifier) async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TermexColors.backgroundSecondary,
        title: Text('确认擦除所有数据',
            style: TextStyle(color: TermexColors.danger, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '此操作将永久删除所有数据，无法恢复。\n请输入主密码并键入 "DELETE ALL" 确认。',
              style: TextStyle(fontSize: 12, color: TermexColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: '主密码'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmCtrl,
              decoration: const InputDecoration(hintText: 'DELETE ALL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: TermexColors.danger),
            child: const Text('擦除'),
          ),
        ],
      ),
    );
    if (result == true && context.mounted) {
      final ok = await notifier.gdprEraseAll(
          passwordCtrl.text, confirmCtrl.text);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('确认文字不正确')),
        );
      }
    }
  }
}

class _DangerSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool danger;

  const _DangerSection({
    required this.title,
    required this.children,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: danger
            ? TermexColors.danger.withOpacity(0.04)
            : TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: danger
              ? TermexColors.danger.withOpacity(0.3)
              : TermexColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: danger ? TermexColors.danger : TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ClearButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: TermexColors.textPrimary,
          side: BorderSide(color: TermexColors.border),
          alignment: Alignment.centerLeft,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
