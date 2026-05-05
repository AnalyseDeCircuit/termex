/// About / version tab — v0.49 spec §5.4.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_version.dart';
import '../../../design/tokens.dart';
import '../../../system/auto_updater.dart';
import '../../../system/state/update_provider.dart';
import '../../../system/url_service.dart';

class AboutTab extends ConsumerWidget {
  const AboutTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(updateStatusProvider);
    final prefs = ref.watch(updatePreferencesProvider);

    final status = statusAsync.when(
      data: (s) => s,
      loading: () => const UpdateStatus.idle(),
      error: (_, __) => const UpdateStatus.idle(),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(),
          const SizedBox(height: 24),
          _UpdateSection(status: status, prefs: prefs),
          const SizedBox(height: 16),
          const _LinksSection(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.terminal, size: 48, color: TermexColors.primary),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Termex',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: TermexColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'v$kAppVersion · $kAppChannel',
              style: const TextStyle(
                fontSize: 12,
                color: TermexColors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'AI 时代永不断线的云端智能工作平台',
              style: TextStyle(fontSize: 11, color: TermexColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _UpdateSection extends ConsumerWidget {
  final UpdateStatus status;
  final UpdatePreferences prefs;

  const _UpdateSection({required this.status, required this.prefs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: TermexColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusLine(status),
          const SizedBox(height: 12),
          Row(
            children: [
              _CheckButton(status: status),
              const SizedBox(width: 8),
              if (status.stage == UpdateStage.available)
                _DownloadButton(status: status),
              if (status.stage == UpdateStage.ready) _ApplyButton(),
            ],
          ),
          const Divider(height: 32),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('自动下载更新', style: TextStyle(fontSize: 12)),
            value: prefs.autoDownload,
            onChanged: (v) => ref
                .read(updatePreferencesProvider.notifier)
                .setAutoDownload(v),
          ),
          Row(
            children: [
              const Text('检查频率:',
                  style: TextStyle(fontSize: 12, color: TermexColors.textSecondary)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: prefs.checkIntervalHours,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('每小时')),
                  DropdownMenuItem(value: 24, child: Text('每天')),
                  DropdownMenuItem(value: 168, child: Text('每周')),
                ],
                onChanged: (h) {
                  if (h != null) {
                    ref.read(updatePreferencesProvider.notifier).setInterval(h);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusLine(UpdateStatus status) {
    final (icon, color, text) = switch (status.stage) {
      UpdateStage.idle => (Icons.check_circle, TermexColors.success, '已是最新版本'),
      UpdateStage.checking =>
        (Icons.hourglass_top, TermexColors.textSecondary, '正在检查...'),
      UpdateStage.available => (
          Icons.new_releases,
          TermexColors.primary,
          '有可用更新 v${status.newVersion ?? "?"}',
        ),
      UpdateStage.downloading => (
          Icons.cloud_download,
          TermexColors.primary,
          '下载中 ${((status.progress ?? 0) * 100).toStringAsFixed(0)}%',
        ),
      UpdateStage.ready => (
          Icons.download_done,
          TermexColors.success,
          '准备就绪 v${status.newVersion ?? "?"}',
        ),
      UpdateStage.failed => (
          Icons.error_outline,
          TermexColors.danger,
          '更新失败: ${status.error ?? "unknown"}',
        ),
    };
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _CheckButton extends ConsumerWidget {
  final UpdateStatus status;
  const _CheckButton({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = status.stage != UpdateStage.checking &&
        status.stage != UpdateStage.downloading;
    return TextButton.icon(
      icon: const Icon(Icons.refresh, size: 14),
      label: const Text('立即检查'),
      onPressed: enabled
          ? () => ref.read(updateServiceProvider).checkForUpdate()
          : null,
    );
  }
}

class _DownloadButton extends ConsumerWidget {
  final UpdateStatus status;
  const _DownloadButton({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      icon: const Icon(Icons.download, size: 14),
      label: Text('下载 v${status.newVersion ?? ""}'),
      onPressed: () => ref.read(updateServiceProvider).downloadUpdate(),
    );
  }
}

class _ApplyButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      icon: const Icon(Icons.refresh, size: 14),
      label: const Text('重启并应用'),
      onPressed: () => ref.read(updateServiceProvider).applyUpdate(),
    );
  }
}

class _LinksSection extends StatelessWidget {
  const _LinksSection();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        TextButton(
          onPressed: () => UrlService.instance.open('https://github.com/termex/termex'),
          child: const Text('GitHub'),
        ),
        TextButton(
          onPressed: () => UrlService.instance.open('https://termex.app'),
          child: const Text('官网'),
        ),
        TextButton(
          onPressed: () => UrlService.instance.open('https://github.com/termex/termex/blob/main/LICENSE'),
          child: const Text('MIT License'),
        ),
      ],
    );
  }
}
