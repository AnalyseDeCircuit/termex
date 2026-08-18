/// Tauri retirement deprecation banner (v0.70.0 Phase 1).
///
/// Shown once at app startup to users upgrading from the Tauri/Vue desktop
/// stack. Renders only when:
///   * the running binary is the Flutter desktop build (Phase 1 ships in
///     both stacks but the Tauri-side variant lives in the legacy code);
///   * the user has not yet dismissed it in this install.
///
/// Dismissal is sticky via SharedPreferences (`termex.tauri_retire_dismissed`),
/// so the banner only appears once per machine — matches the v0.70.0 doc's
/// "首次启动时 toast 显示 + 不再提醒按钮" requirement.
///
/// Embed in the desktop shell above the tab bar, or render the dialog form
/// via [showTauriRetirementDialog] from the welcome / menu flows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/tokens.dart';
import 'url_service.dart';

const String _kDismissKey = 'termex.tauri_retire_dismissed';
const String _kMigrationDocUrl =
    'https://termex.app/docs/migration#tauri-retirement';
const String _kRetirementPlanUrl =
    'https://github.com/termex/termex/blob/main/docs/iterations/v0.70.0-pc-tauri-retirement.md';

/// Async-loaded dismissal flag. The banner watches this and renders nothing
/// when the user has clicked "不再提醒".
final tauriRetirementDismissedProvider =
    FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kDismissKey) ?? false;
});

class TauriRetirementBanner extends ConsumerWidget {
  const TauriRetirementBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed =
        ref.watch(tauriRetirementDismissedProvider).valueOrNull ?? true;
    if (dismissed) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: context.colors.warning, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 14, color: context.colors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '欢迎使用 Flutter 桌面版！Tauri/Vue 老栈即将停止构建 '
              '(v0.78.0)，源码物理删除排期 v0.80.0。数据库 + 凭据完全共享，'
              '无需手动迁移。',
              style: TextStyle(
                  fontSize: 11, color: context.colors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => UrlService.instance.open(_kMigrationDocUrl),
            child: Text('查看迁移指南',
                style: TextStyle(
                    fontSize: 11, color: context.colors.primary)),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(_kDismissKey, true);
              ref.invalidate(tauriRetirementDismissedProvider);
            },
            child: Text('不再提醒',
                style: TextStyle(
                    fontSize: 11, color: context.colors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// Modal variant of the banner, suitable for first-launch onboarding or a
/// menu-triggered explainer dialog. Returns when the user closes the dialog.
Future<void> showTauriRetirementDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.colors.backgroundSecondary,
      title: Row(
        children: [
          Icon(Icons.info_outline,
              size: 18, color: ctx.colors.warning),
          const SizedBox(width: 8),
          Text('Tauri 老栈退役计划',
              style: TextStyle(
                  fontSize: 14, color: ctx.colors.textPrimary)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Termex 在 v0.69 起进入 Tauri/Vue 桌面老栈退役期。'
              'Flutter 桌面端已在 v0.77.0 完成功能对齐，'
              'v0.78.0 起停止 Tauri 构建。',
              style: TextStyle(
                  fontSize: 12, color: ctx.colors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              '• v0.69 — Deprecation 通知 ✅\n'
              '• v0.70 — 默认安装切换到 Flutter ✅\n'
              '• v0.77 — Flutter 功能对齐验收 ✅\n'
              '• v0.78 — CI 停止构建 Tauri 产物（计划中）\n'
              '• v0.80 — 物理删除 src-tauri/ + src/',
              style: TextStyle(
                  fontSize: 11, color: ctx.colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              '数据库 (SQLCipher) 与 Keychain 凭据完全共享，'
              '无需手动迁移：直接装 Flutter 版即可，主密码一致即可见全部数据。',
              style: TextStyle(
                  fontSize: 12, color: ctx.colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '已知行为差异：按钮圆角 / 字体度量 / Cmd+N 新窗口 / 打印视图。',
              style: TextStyle(
                  fontSize: 11, color: ctx.colors.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => UrlService.instance.open(_kRetirementPlanUrl),
          child: Text('查看完整退役计划',
              style: TextStyle(color: ctx.colors.textSecondary)),
        ),
        TextButton(
          onPressed: () => UrlService.instance.open(_kMigrationDocUrl),
          child: Text('迁移指南',
              style: TextStyle(color: ctx.colors.primary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('我知道了'),
        ),
      ],
    ),
  );
}
