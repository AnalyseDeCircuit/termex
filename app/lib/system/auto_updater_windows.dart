/// Windows auto-updater — delegates install to the MSIX App Installer.
///
/// The `ms-appinstaller:` protocol hands off to the OS-level installer,
/// which handles differential updates, silent apply, and rollback.
library;

import 'update_service.dart';
import 'url_service.dart';

class WindowsAutoUpdater extends UpdateService {
  WindowsAutoUpdater({
    required super.currentVersion,
    required super.channel,
    required super.baseUrl,
    required super.fetchAppcast,
    UrlService? urlService,
  }) : super(
          handoffInstaller: (url) async {
            final svc = urlService ?? UrlService.instance;
            // Open the https download URL; production build wraps this in a
            // `ms-appinstaller:?source=` protocol handler via a platform
            // channel.  See docs/tech-debt.md T-2.
            if (url.startsWith('https://')) {
              await svc.open(url);
            }
          },
        );
}
