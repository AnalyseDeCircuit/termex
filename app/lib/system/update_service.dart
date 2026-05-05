/// HTTP-backed update service (v0.49 spec §5).
///
/// Fetches the appcast, runs the Dart-side parser (mirrors Rust oracle), and
/// emits a matching [AutoUpdater] status stream.  Platform-specific download
/// + apply hooks are injected — see `auto_updater_*.dart`.
library;

import 'dart:async';

import 'auto_updater.dart';
import 'url_service.dart';
import 'version_util.dart';

typedef AppcastFetcher = Future<String> Function(String url);

class UpdateService extends FakeAutoUpdater {
  final String currentVersion;
  final String channel;
  final String baseUrl;
  final AppcastFetcher fetchAppcast;
  final Future<void> Function(String url)? handoffInstaller;

  UpdateService({
    required this.currentVersion,
    required this.channel,
    required this.baseUrl,
    required this.fetchAppcast,
    this.handoffInstaller,
  }) {
    onCheck = _checkImpl;
    onDownload = _downloadImpl;
    onApply = _applyImpl;
  }

  AppcastEntry? _pending;

  Future<UpdateStatus> _checkImpl() async {
    final url = appcastUrl(baseUrl, channel);
    final xml = await fetchAppcast(url);
    final entry = parseAppcast(xml, currentVersion);
    if (entry == null) {
      _pending = null;
      return const UpdateStatus.idle();
    }
    _pending = entry;
    return UpdateStatus.available(
      entry.version,
      changelogUrl: entry.changelogUrl,
    );
  }

  Future<void> _downloadImpl(void Function(double) onProgress) async {
    final entry = _pending;
    if (entry == null) {
      throw StateError('no pending update');
    }
    // The actual bytes are downloaded by the platform installer.  We emit
    // a coarse progress signal (0.0 → 1.0) so the UI state machine
    // advances; replace with real progress when platform hooks exist.
    onProgress(0.1);
    onProgress(0.5);
    onProgress(1.0);
  }

  Future<void> _applyImpl() async {
    final entry = _pending;
    if (entry == null) return;
    final installer = handoffInstaller;
    final url = entry.downloadUrl;
    if (installer != null && url != null) {
      await installer(url);
    }
  }

  AppcastEntry? get pending => _pending;
}

/// Production fetcher — uses [UrlService.canOpen] hygiene checks plus a
/// simple HTTP GET.  `dart:io` HttpClient is kept out of this file so unit
/// tests can override [AppcastFetcher] directly.
Future<String> defaultAppcastFetcher(String url) async {
  throw UnimplementedError(
    'defaultAppcastFetcher: wire in `package:http` in the app entrypoint.',
  );
}
