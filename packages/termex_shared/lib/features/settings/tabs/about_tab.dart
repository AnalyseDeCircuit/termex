/// About / version tab — v0.49 spec §5.4.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/api.dart' as bridge;

import '../../../app_version.dart';
import '../../../design/tokens.dart';
import '../../../l10n/app_localizations.dart';
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
          const SizedBox(height: 24),
          const _SessionPoolSection(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.terminal, size: 48, color: context.colors.primary),
        const SizedBox(width: 16),
        // Expanded lets the title / version / tagline reflow within the
        // available width on narrow viewports instead of forcing a
        // horizontal overflow when paired with the fixed-size icon.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Termex',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'v$kAppVersion · $kAppChannel',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.aboutTagline,
                style: TextStyle(
                    fontSize: 11, color: context.colors.textSecondary),
              ),
            ],
          ),
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
        border: Border.all(color: context.colors.border),
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
          Builder(builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.aboutAutoDownload,
                      style: const TextStyle(fontSize: 12)),
                  value: prefs.autoDownload,
                  onChanged: (v) => ref
                      .read(updatePreferencesProvider.notifier)
                      .setAutoDownload(v),
                ),
                Row(
                  children: [
                    // Flexible lets the label ellipsise on narrow
                    // viewports instead of forcing a horizontal
                    // overflow when paired with the fixed-width
                    // DropdownButton trailing it.
                    Flexible(
                      child: Text(l10n.aboutCheckFrequencyLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: prefs.checkIntervalHours,
                      isDense: true,
                      items: [
                        DropdownMenuItem(
                            value: 1, child: Text(l10n.aboutFrequencyHourly)),
                        DropdownMenuItem(
                            value: 24, child: Text(l10n.aboutFrequencyDaily)),
                        DropdownMenuItem(
                            value: 168,
                            child: Text(l10n.aboutFrequencyWeekly)),
                      ],
                      onChanged: (h) {
                        if (h != null) {
                          ref
                              .read(updatePreferencesProvider.notifier)
                              .setInterval(h);
                        }
                      },
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _statusLine(UpdateStatus status) {
    return Builder(builder: (context) {
      final l10n = AppLocalizations.of(context);
      final v = status.newVersion ?? "?";
      final (icon, color, text) = switch (status.stage) {
        UpdateStage.idle =>
          (Icons.check_circle, context.colors.success, l10n.updateUpToDate),
        UpdateStage.checking => (
            Icons.hourglass_top,
            context.colors.textSecondary,
            l10n.updateChecking
          ),
        UpdateStage.available => (
            Icons.new_releases,
            context.colors.primary,
            l10n.aboutUpdateAvailable(v),
          ),
        UpdateStage.downloading => (
            Icons.cloud_download,
            context.colors.primary,
            l10n.aboutUpdateDownloadingPercent(
                ((status.progress ?? 0) * 100).toStringAsFixed(0)),
          ),
        UpdateStage.ready => (
            Icons.download_done,
            context.colors.success,
            l10n.aboutUpdateReady(v),
          ),
        UpdateStage.failed => (
            Icons.error_outline,
            context.colors.danger,
            l10n.aboutUpdateFailed(status.error ?? "unknown"),
          ),
      };
      return Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
                fontSize: 13, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      );
    });
  }
}

class _CheckButton extends ConsumerWidget {
  final UpdateStatus status;
  const _CheckButton({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = status.stage != UpdateStage.checking &&
        status.stage != UpdateStage.downloading;
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      icon: const Icon(Icons.refresh, size: 14),
      label: Text(l10n.aboutCheckNow),
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
    final l10n = AppLocalizations.of(context);
    return FilledButton.icon(
      icon: const Icon(Icons.download, size: 14),
      label: Text(l10n.aboutDownloadButton(status.newVersion ?? "")),
      onPressed: () => ref.read(updateServiceProvider).downloadUpdate(),
    );
  }
}

class _ApplyButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.icon(
      icon: const Icon(Icons.refresh, size: 14),
      label: Text(l10n.aboutApplyAndRestart),
      onPressed: () => ref.read(updateServiceProvider).applyUpdate(),
    );
  }
}

class _LinksSection extends StatelessWidget {
  const _LinksSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 12,
      children: [
        TextButton(
          onPressed: () =>
              UrlService.instance.open('https://github.com/termex/termex'),
          child: const Text('GitHub'),
        ),
        TextButton(
          onPressed: () => UrlService.instance.open('https://termex.app'),
          child: Text(l10n.aboutWebsite),
        ),
        TextButton(
          onPressed: () => UrlService.instance
              .open('https://github.com/termex/termex/blob/main/LICENSE'),
          child: const Text('MIT License'),
        ),
      ],
    );
  }
}

// ─── Session pool stats (v0.68.0 G2) ─────────────────────────────────────────

/// Debug-only panel listing the proxy session pool. Surfaces ref-count,
/// uptime, and bytes-transferred per pooled upstream so users can verify
/// connection reuse when multiple servers share a SOCKS5 / HTTP proxy or
/// jump host. Pulls a fresh snapshot from the bridge on every refresh.
final _poolStatsProvider = FutureProvider.autoDispose<List<bridge.ProxyPoolStat>>(
  (ref) => bridge.sessionPoolStats(),
);

class _SessionPoolSection extends ConsumerWidget {
  const _SessionPoolSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(_poolStatsProvider);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_outlined,
                  size: 14, color: context.colors.textSecondary),
              const SizedBox(width: 6),
              Text(l10n.aboutSessionPoolTitle,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary)),
              const Spacer(),
              IconButton(
                tooltip: l10n.commonRefresh,
                icon: Icon(Icons.refresh,
                    size: 14, color: context.colors.textSecondary),
                onPressed: () => ref.invalidate(_poolStatsProvider),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.aboutSessionPoolHelp,
            style: TextStyle(
                fontSize: 10, color: context.colors.textMuted),
          ),
          const SizedBox(height: 10),
          asyncStats.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text(l10n.commonLoadFailed(e.toString()),
                style: TextStyle(
                    fontSize: 11, color: context.colors.danger)),
            data: (rows) => rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l10n.aboutSessionPoolEmpty,
                        style: TextStyle(
                            fontSize: 11, color: context.colors.textMuted)),
                  )
                : Column(
                    children: rows.map(_PoolStatRow.new).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PoolStatRow extends StatelessWidget {
  final bridge.ProxyPoolStat stat;

  const _PoolStatRow(this.stat);

  String _formatBytes(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    if (n < 1024 * 1024 * 1024) {
      return '${(n / 1024 / 1024).toStringAsFixed(2)} MB';
    }
    return '${(n / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _uptime() {
    final ageSec =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - stat.connectedSince;
    if (ageSec < 60) return '${ageSec}s';
    if (ageSec < 3600) return '${ageSec ~/ 60}m';
    if (ageSec < 86400) return '${ageSec ~/ 3600}h';
    return '${ageSec ~/ 86400}d';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(stat.proxyType,
                style: TextStyle(
                    fontSize: 9,
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stat.host}:${stat.port}'
                  '${stat.username != null ? '  (${stat.username})' : ''}',
                  style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textPrimary,
                      fontFamily: 'monospace'),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('refs: ${stat.refCount}',
                        style: TextStyle(
                            fontSize: 10, color: context.colors.success)),
                    const SizedBox(width: 10),
                    Text('uptime: ${_uptime()}',
                        style: TextStyle(
                            fontSize: 10, color: context.colors.textSecondary)),
                    const SizedBox(width: 10),
                    Text(_formatBytes(stat.bytesTransferred.toInt()),
                        style: TextStyle(
                            fontSize: 10, color: context.colors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
