/// Backup / export / import settings tab.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../state/backup_history_service.dart';
import '../state/settings_provider.dart';
import '../widgets/setting_row.dart';

class BackupTab extends ConsumerWidget {
  const BackupTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider).settings;
    final notifier = ref.read(settingsProvider.notifier);
    final history = ref.watch(backupHistoryProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SettingRow(
          label: l10n.backupAutoFreqLabel,
          hint: l10n.backupAutoFreqHint,
          child: DropdownButton<BackupFrequency>(
            value: settings.backupFrequency,
            dropdownColor: context.colors.backgroundSecondary,
            items: [
              DropdownMenuItem(
                  value: BackupFrequency.off, child: Text(l10n.backupFreqOff)),
              DropdownMenuItem(
                  value: BackupFrequency.daily,
                  child: Text(l10n.backupFreqDaily)),
              DropdownMenuItem(
                  value: BackupFrequency.weekly,
                  child: Text(l10n.backupFreqWeekly)),
            ],
            onChanged: (v) =>
                notifier.update(settings.copyWith(backupFrequency: v!)),
            style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.backupEncryptionNote,
          style: TextStyle(
              fontSize: 11, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _backupNow(context, ref, notifier),
          icon: const Icon(Icons.save_alt, size: 14),
          label: Text(l10n.backupNow, style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _importWithPassword(context, notifier),
          icon: const Icon(Icons.download_rounded, size: 14),
          label: Text(l10n.backupImportConfig,
              style: const TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        _HistorySection(history: history),
      ],
    );
  }

  Future<void> _backupNow(
    BuildContext context,
    WidgetRef ref,
    SettingsNotifier notifier,
  ) async {
    final l10n = AppLocalizations.of(context);
    final password =
        await _promptPassword(context, l10n.backupEnterEncryptPassword);
    if (password == null || password.isEmpty) return;

    final stamp = DateTime.now();
    final fname =
        'termex-backup-${stamp.toIso8601String().replaceAll(':', '-').split('.').first}.termex';
    final history = ref.read(backupHistoryProvider.notifier);

    try {
      await notifier.exportConfig(fname, password);
      int? sizeBytes;
      try {
        sizeBytes = await File(fname).length();
      } catch (_) {}
      await history.record(BackupRecord(
        timestamp: stamp,
        path: fname,
        sizeBytes: sizeBytes,
        status: BackupStatus.success,
      ));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupDone(fname))),
        );
      }
    } catch (e) {
      await history.record(BackupRecord(
        timestamp: stamp,
        path: fname,
        status: BackupStatus.failed,
        error: e.toString(),
      ));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _importWithPassword(
      BuildContext context, SettingsNotifier notifier) async {
    final l10n = AppLocalizations.of(context);
    final password =
        await _promptPassword(context, l10n.backupEnterDecryptPassword);
    if (password == null || password.isEmpty) return;
    await notifier.importConfig('termex-backup.termex', password);
  }

  Future<String?> _promptPassword(BuildContext context, String title) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(hintText: l10n.backupPasswordHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l10n.backupConfirm),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends ConsumerWidget {
  final AsyncValue<List<BackupRecord>> history;

  const _HistorySection({required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.backupHistoryTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () =>
                  ref.read(backupHistoryProvider.notifier).clear(),
              icon: const Icon(Icons.delete_sweep_outlined, size: 14),
              label: Text(l10n.backupHistoryClear,
                  style: const TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.backupHistoryMaxNote(
              BackupHistoryNotifier.maxEntries.toString()),
          style: TextStyle(
              fontSize: 11, color: context.colors.textMuted),
        ),
        const SizedBox(height: 8),
        history.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => Text(
            l10n.commonLoadFailed(e.toString()),
            style:
                TextStyle(fontSize: 11, color: context.colors.danger),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.backupHistoryEmpty,
                  style: TextStyle(
                      fontSize: 12, color: context.colors.textMuted),
                ),
              );
            }
            return Column(
              children: entries.map(_HistoryRow.new).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final BackupRecord record;

  const _HistoryRow(this.record);

  String _formatSize(int? bytes) {
    if (bytes == null) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  String _formatTime(DateTime t) {
    final l = t.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${pad(l.month)}-${pad(l.day)} ${pad(l.hour)}:${pad(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final isOk = record.status == BackupStatus.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isOk
              ? context.colors.success.withValues(alpha: 0.3)
              : context.colors.danger.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle_outline : Icons.error_outline,
            size: 14,
            color: isOk ? context.colors.success : context.colors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.path,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textPrimary,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatTime(record.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatSize(record.sizeBytes),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (record.error != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.error!,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.danger,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
