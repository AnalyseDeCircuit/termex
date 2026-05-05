/// macOS auto-updater — Sparkle-compatible appcast polling.
///
/// Wraps [UpdateService] with a macOS-specific installer handoff: opens the
/// DMG URL via `url_launcher` so Safari downloads + mounts it, and the user
/// drags the new app to Applications.  A real Sparkle integration (delta
/// patches, silent apply) is deferred to v0.50 — see `docs/tech-debt.md` T-2.
library;

import 'dart:async';

import 'update_service.dart';
import 'url_service.dart';

class MacAutoUpdater extends UpdateService {
  MacAutoUpdater({
    required super.currentVersion,
    required super.channel,
    required super.baseUrl,
    required super.fetchAppcast,
    UrlService? urlService,
  }) : super(
          handoffInstaller: (url) async {
            final svc = urlService ?? UrlService.instance;
            await svc.open(url);
          },
        );
}
