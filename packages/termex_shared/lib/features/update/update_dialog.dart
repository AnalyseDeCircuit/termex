/// In-app "Check for updates" dialog.
///
/// OSS flow:
///   1. `bridge.updateConfigGet()` → release channel + auto-check pref
///   2. `bridge.appcastUrl(channel)` → appcast XML endpoint
///   3. Direct HTTP fetch via [HttpClient] (the OSS bridge does not ship
///      its own networking — heavy auto-update logic lives in Pro's
///      tauri-plugin-updater equivalent)
///   4. `bridge.parseAppcast(xml, currentVersion)` → [UpdateManifest]
///   5. `bridge.isUpdateAvailable(current, remote)` → bool
///   6. Show release notes + "查看下载页" (opens [UpdateManifest.releaseUrl])
///
/// In-app download + verify + restart is intentionally absent in OSS —
/// matches the legacy Tauri OSS build, which gated tauri-plugin-updater
/// behind the `private` Cargo feature.
///
/// v0.77.0 PC final parity: closes P0-6 ("Update Dialog 在 Flutter 桌面
/// 没有 UI") from the iteration plan.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/api.dart' as bridge;
import 'package:url_launcher/url_launcher.dart';

import '../../app_version.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../icons/termex_icons.dart';
import '../../widgets/button.dart';
import '../../widgets/dialog.dart';

Future<void> showUpdateDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showTermexDialog<void>(
    context: context,
    title: l10n.updateDialogTitle,
    size: DialogSize.medium,
    body: const SizedBox(
      width: 460,
      height: 320,
      child: _UpdateDialogBody(),
    ),
  );
}

class _UpdateDialogBody extends ConsumerStatefulWidget {
  const _UpdateDialogBody();

  @override
  ConsumerState<_UpdateDialogBody> createState() => _UpdateDialogBodyState();
}

enum _Phase { checking, upToDate, available, error }

class _UpdateDialogBodyState extends ConsumerState<_UpdateDialogBody> {
  _Phase _phase = _Phase.checking;
  bridge.UpdateManifest? _manifest;
  bool _isAvailable = false;
  String? _errorMessage;
  String _channel = 'stable';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _phase = _Phase.checking;
      _errorMessage = null;
    });
    try {
      final cfg = await bridge.updateConfigGet();
      _channel = cfg.channel;
      final url = await bridge.appcastUrl(channel: cfg.channel);
      final xml = await _fetchXml(url).timeout(const Duration(seconds: 10));
      final manifest = await bridge.parseAppcast(
        xml: xml,
        currentVersion: kAppVersion,
      );
      final available = await bridge.isUpdateAvailable(
        current: kAppVersion,
        remote: manifest.availableVersion ?? kAppVersion,
      );
      await bridge.updateMarkChecked(
        nowRfc3339: DateTime.now().toUtc().toIso8601String(),
      );
      if (!mounted) return;
      setState(() {
        _manifest = manifest;
        _isAvailable = available;
        _phase = available ? _Phase.available : _Phase.upToDate;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<String> _fetchXml(String url) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw 'HTTP ${resp.statusCode}';
      }
      final bytes = <int>[];
      await for (final chunk in resp) {
        bytes.addAll(chunk);
      }
      return String.fromCharCodes(bytes);
    } finally {
      client.close();
    }
  }

  /// Download size from the appcast enclosure, shown beside the version.
  static String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openReleasePage() async {
    // The appcast points at the changelog; the download URL is what the
    // in-app updater consumes, so it is not what "view the release page"
    // should open.
    final url = _manifest?.changelogUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VersionRow(channel: _channel),
        const SizedBox(height: TermexSpacing.md),
        Expanded(child: _phaseBody()),
        const SizedBox(height: TermexSpacing.md),
        _actions(),
      ],
    );
  }

  Widget _phaseBody() {
    final l10n = AppLocalizations.of(context);
    switch (_phase) {
      case _Phase.checking:
        return _statusBox(
          icon: TermexIcons.refresh,
          color: context.colors.primary,
          title: l10n.updateInProgress,
          message: null,
        );
      case _Phase.upToDate:
        return _statusBox(
          icon: TermexIcons.connect,
          color: context.colors.success,
          title: l10n.updateUpToDateTitle,
          message: l10n.updateUpToDateDetail(kAppVersion, _channel),
        );
      case _Phase.error:
        return _statusBox(
          icon: TermexIcons.help,
          color: context.colors.danger,
          title: l10n.updateCheckFailedTitle,
          message: _errorMessage,
        );
      case _Phase.available:
        return _availableBody();
    }
  }

  Widget _availableBody() {
    final l10n = AppLocalizations.of(context);
    final m = _manifest!;
    return Container(
      padding: const EdgeInsets.all(TermexSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border.all(color: context.colors.border, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TermexIconWidget(
                TermexIcons.download,
                size: 14,
                color: context.colors.primary,
              ),
              const SizedBox(width: TermexSpacing.sm),
              Text(
                l10n.updateNewVersionTitle(
                    m.availableVersion ?? m.currentVersion),
                style: TermexTypography.body.copyWith(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (m.sizeBytes != null)
                Text(
                  _formatSize(m.sizeBytes!),
                  style: TermexTypography.caption.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: TermexSpacing.sm),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                m.changelogUrl ?? l10n.updateNoReleaseNotes,
                style: TermexTypography.caption.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBox({
    required IconData icon,
    required Color color,
    required String title,
    String? message,
  }) {
    return Container(
      padding: const EdgeInsets.all(TermexSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border.all(color: context.colors.border, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TermexIconWidget(icon, size: 28, color: color),
            const SizedBox(height: TermexSpacing.sm),
            Text(
              title,
              style: TermexTypography.body.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: TermexSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.md),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TermexTypography.caption.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actions() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        if (_phase == _Phase.available && _isAvailable)
          TermexButton(
            label: l10n.updateViewDownloadPage,
            variant: ButtonVariant.primary,
            onPressed: _openReleasePage,
          ),
        if (_phase == _Phase.error || _phase == _Phase.upToDate) ...[
          TermexButton(
            label: l10n.updateRecheck,
            variant: ButtonVariant.ghost,
            onPressed: _check,
          ),
        ],
        const Spacer(),
        Builder(
          builder: (ctx) => TermexButton(
            label: l10n.commonClose,
            variant: ButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
          ),
        ),
      ],
    );
  }
}

class _VersionRow extends StatelessWidget {
  final String channel;
  const _VersionRow({required this.channel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Text(
          l10n.updateCurrentVersion,
          style: TermexTypography.caption.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          'v$kAppVersion · $channel',
          style: TermexTypography.caption.copyWith(
            color: context.colors.textPrimary,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
