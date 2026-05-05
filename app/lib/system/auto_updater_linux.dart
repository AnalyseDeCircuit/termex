/// Linux auto-updater — AppImageUpdate handoff.
///
/// Opens the download URL so the user can grab the new `.AppImage` (or
/// `.deb` / `.rpm`) manually.  The `appimageupdatetool --self-update`
/// integration is deferred — see `docs/tech-debt.md` T-2.
library;

import 'update_service.dart';
import 'url_service.dart';

class LinuxAutoUpdater extends UpdateService {
  LinuxAutoUpdater({
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
