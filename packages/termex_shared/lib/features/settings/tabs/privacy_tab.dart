/// Privacy settings — history clearing + GDPR full erase.
///
/// v0.77.0 PC final parity: replaced stock Material `AlertDialog` /
/// `OutlinedButton` widgets with the project's own [`showTermexDialog`]
/// / [`TermexButton`] so the surface looks like the rest of the app.
/// Also added confirmation prompts for the three "clear …" actions —
/// they previously erased data on a single tap with no second chance.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../../icons/termex_icons.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialog.dart';
import '../../../widgets/text_field.dart';
import '../../../widgets/toast.dart';
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
          hint: '保留账号设置与凭据，仅清空相应历史。',
          children: [
            _ClearButton(
              label: '清除最近连接历史',
              icon: TermexIcons.history,
              onTap: () => _confirmAndClear(
                context,
                title: '清除最近连接历史',
                message: '将删除全部"最近连接"记录，已保存的服务器配置不受影响。',
                doClear: () async {
                  await notifier.clearConnectionHistory();
                  ToastController.success('已清除连接历史');
                },
              ),
            ),
            _ClearButton(
              label: '清除 AI 对话历史',
              icon: TermexIcons.ai,
              onTap: () => _confirmAndClear(
                context,
                title: '清除 AI 对话历史',
                message: '将永久删除所有 AI 对话与消息。Provider 配置 / API Key 保留。',
                doClear: () async {
                  await notifier.clearAiConversations();
                  ToastController.success('已清除 AI 对话历史');
                },
              ),
            ),
            _ClearButton(
              label: '清除 Snippet 使用统计',
              icon: TermexIcons.snippet,
              onTap: () => _confirmAndClear(
                context,
                title: '清除 Snippet 使用统计',
                message: '将重置所有 Snippet 的使用次数，Snippet 本身保留。',
                doClear: () async {
                  await notifier.clearSnippetStats();
                  ToastController.success('已清除使用统计');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _DangerSection(
          title: 'GDPR 数据擦除',
          hint:
              '永久删除所有本地数据（服务器配置、凭据、对话、设置）。此操作不可恢复。',
          danger: true,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TermexButton(
                label: '擦除所有数据',
                variant: ButtonVariant.danger,
                icon: const TermexIconWidget(TermexIcons.delete, size: 14),
                onPressed: () => _showGdprDialog(context, notifier),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmAndClear(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() doClear,
  }) async {
    final ok = await showConfirmDialog(
      context: context,
      title: title,
      message: message,
      confirmLabel: '清除',
      destructive: true,
    );
    if (ok == true) {
      await doClear();
    }
  }

  Future<void> _showGdprDialog(
    BuildContext context,
    SettingsNotifier notifier,
  ) async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final ok = await showTermexDialog<bool>(
      context: context,
      title: '确认擦除所有数据',
      size: DialogSize.small,
      body: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '此操作将永久删除所有数据，无法恢复。\n请输入主密码并键入 "DELETE ALL" 确认。',
              style: TextStyle(
                fontSize: 12,
                color: TermexColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            const Text('主密码',
                style: TextStyle(
                    fontSize: 11, color: TermexColors.textSecondary)),
            const SizedBox(height: 4),
            TermexTextField(
              controller: passwordCtrl,
              obscureText: true,
              placeholder: '主密码',
            ),
            const SizedBox(height: 10),
            const Text('确认文本',
                style: TextStyle(
                    fontSize: 11, color: TermexColors.textSecondary)),
            const SizedBox(height: 4),
            TermexTextField(
              controller: confirmCtrl,
              placeholder: 'DELETE ALL',
            ),
          ],
        ),
      ),
      actions: [
        Builder(
          builder: (ctx) => TermexButton(
            label: '取消',
            variant: ButtonVariant.ghost,
            onPressed: () =>
                Navigator.of(ctx, rootNavigator: true).pop(false),
          ),
        ),
        Builder(
          builder: (ctx) => TermexButton(
            label: '擦除',
            variant: ButtonVariant.danger,
            onPressed: () =>
                Navigator.of(ctx, rootNavigator: true).pop(true),
          ),
        ),
      ],
    );
    if (ok == true && context.mounted) {
      final success = await notifier.gdprEraseAll(
        passwordCtrl.text,
        confirmCtrl.text,
      );
      if (!success && context.mounted) {
        ToastController.error('确认文字不正确或主密码错误');
      } else if (success && context.mounted) {
        ToastController.success('数据已擦除');
      }
    }
  }
}

// ─── Section card ─────────────────────────────────────────────────────────

class _DangerSection extends StatelessWidget {
  final String title;
  final String? hint;
  final List<Widget> children;
  final bool danger;

  const _DangerSection({
    required this.title,
    required this.children,
    this.hint,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: danger
            ? TermexColors.danger.withOpacity(0.05)
            : TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: danger
              ? TermexColors.danger.withOpacity(0.4)
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
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: const TextStyle(
                fontSize: 11,
                color: TermexColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// ─── Clear-history button ─────────────────────────────────────────────────

class _ClearButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ClearButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? TermexColors.backgroundTertiary
                  : const Color(0x00000000),
              border: Border.all(color: TermexColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                TermexIconWidget(
                  widget.icon,
                  size: 12,
                  color: TermexColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: TermexColors.textPrimary,
                    ),
                  ),
                ),
                const TermexIconWidget(
                  TermexIcons.chevronRight,
                  size: 12,
                  color: TermexColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
