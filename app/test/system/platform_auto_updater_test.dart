import 'package:flutter_test/flutter_test.dart';

import 'package:termex/system/auto_updater.dart';
import 'package:termex/system/auto_updater_linux.dart';
import 'package:termex/system/auto_updater_macos.dart';
import 'package:termex/system/auto_updater_windows.dart';

const _xml = '''
  <rss><channel><item>
    <sparkle:version>0.49.0</sparkle:version>
    <enclosure url="https://termex.app/dl/termex-0.49.0.dmg" length="1"/>
  </item></channel></rss>''';

Future<String> _fetch(_) async => _xml;

void main() {
  group('MacAutoUpdater', () {
    test('check → available', () async {
      final u = MacAutoUpdater(
        currentVersion: '0.48.0',
        channel: 'stable',
        baseUrl: 'https://termex.app/updates',
        fetchAppcast: _fetch,
      );
      expect(await u.checkForUpdate(), isTrue);
      expect(u.current.stage, UpdateStage.available);
      u.dispose();
    });

    test('applyUpdate hands DMG url to installer without crashing', () async {
      final u = MacAutoUpdater(
        currentVersion: '0.48.0',
        channel: 'stable',
        baseUrl: 'https://termex.app/updates',
        fetchAppcast: _fetch,
      );
      await u.checkForUpdate();
      await u.downloadUpdate();
      await u.applyUpdate();
      expect(u.current.stage, UpdateStage.ready);
      u.dispose();
    });
  });

  group('WindowsAutoUpdater', () {
    test('check → available', () async {
      final u = WindowsAutoUpdater(
        currentVersion: '0.48.0',
        channel: 'stable',
        baseUrl: 'https://termex.app/updates',
        fetchAppcast: _fetch,
      );
      expect(await u.checkForUpdate(), isTrue);
      u.dispose();
    });
  });

  group('LinuxAutoUpdater', () {
    test('check → available', () async {
      final u = LinuxAutoUpdater(
        currentVersion: '0.48.0',
        channel: 'stable',
        baseUrl: 'https://termex.app/updates',
        fetchAppcast: _fetch,
      );
      expect(await u.checkForUpdate(), isTrue);
      u.dispose();
    });
  });
}
