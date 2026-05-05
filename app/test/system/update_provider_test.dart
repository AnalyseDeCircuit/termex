import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:termex/system/auto_updater.dart';
import 'package:termex/system/update_service.dart';
import 'package:termex/system/state/update_provider.dart';

UpdateService _fakeSvc(String xml) => UpdateService(
      currentVersion: '0.48.0',
      channel: 'stable',
      baseUrl: 'https://example.com',
      fetchAppcast: (_) async => xml,
    );

void main() {
  group('UpdatePreferencesNotifier', () {
    test('default preferences', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final prefs = c.read(updatePreferencesProvider);
      expect(prefs.channel, 'stable');
      expect(prefs.autoDownload, isFalse);
      expect(prefs.checkIntervalHours, 24);
    });

    test('setChannel updates state', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(updatePreferencesProvider.notifier).setChannel('beta');
      expect(c.read(updatePreferencesProvider).channel, 'beta');
    });

    test('setAutoDownload updates state', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(updatePreferencesProvider.notifier).setAutoDownload(true);
      expect(c.read(updatePreferencesProvider).autoDownload, isTrue);
    });

    test('setInterval rejects non-positive', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(updatePreferencesProvider.notifier).setInterval(0);
      expect(c.read(updatePreferencesProvider).checkIntervalHours, 24);
      c.read(updatePreferencesProvider.notifier).setInterval(168);
      expect(c.read(updatePreferencesProvider).checkIntervalHours, 168);
    });
  });

  group('updateStatusProvider', () {
    test('throws without override', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(() => c.read(updateServiceProvider), throwsUnimplementedError);
    });

    test('streams status from overridden service', () async {
      const xml = '''
        <rss><channel><item>
          <sparkle:version>0.49.0</sparkle:version>
          <enclosure url="u" length="1"/>
        </item></channel></rss>''';
      final svc = _fakeSvc(xml);
      addTearDown(svc.dispose);

      final c = ProviderContainer(overrides: [
        updateServiceProvider.overrideWithValue(svc),
      ]);
      addTearDown(c.dispose);

      final sub = c.listen(updateStatusProvider, (_, __) {});
      addTearDown(sub.close);

      await svc.checkForUpdate();
      await Future<void>.delayed(Duration.zero);

      final status = c.read(updateStatusProvider);
      expect(status.whenOrNull(data: (s) => s.stage),
          equals(UpdateStage.available));
    });
  });
}
