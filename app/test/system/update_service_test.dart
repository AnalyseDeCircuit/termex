import 'package:flutter_test/flutter_test.dart';

import 'package:termex/system/auto_updater.dart';
import 'package:termex/system/update_service.dart';

void main() {
  const xmlWithUpdate = '''
    <rss><channel><item>
      <sparkle:version>0.49.0</sparkle:version>
      <enclosure url="https://termex.app/dl/Termex-0.49.0.dmg" length="1"/>
    </item></channel></rss>''';

  const xmlNoUpdate = '''
    <rss><channel><item>
      <sparkle:version>0.48.0</sparkle:version>
      <enclosure url="u" length="1"/>
    </item></channel></rss>''';

  test('checkForUpdate returns true and exposes pending entry', () async {
    final svc = UpdateService(
      currentVersion: '0.48.0',
      channel: 'stable',
      baseUrl: 'https://example.com',
      fetchAppcast: (_) async => xmlWithUpdate,
    );
    final result = await svc.checkForUpdate();
    expect(result, isTrue);
    expect(svc.current.stage, UpdateStage.available);
    expect(svc.pending?.version, '0.49.0');
    svc.dispose();
  });

  test('checkForUpdate returns false when no update', () async {
    final svc = UpdateService(
      currentVersion: '0.49.0',
      channel: 'stable',
      baseUrl: 'https://example.com',
      fetchAppcast: (_) async => xmlNoUpdate,
    );
    expect(await svc.checkForUpdate(), isFalse);
    expect(svc.current.stage, UpdateStage.idle);
    expect(svc.pending, isNull);
    svc.dispose();
  });

  test('fetch error surfaces as failed status', () async {
    final svc = UpdateService(
      currentVersion: '0.48.0',
      channel: 'stable',
      baseUrl: 'https://example.com',
      fetchAppcast: (_) async => throw Exception('offline'),
    );
    final result = await svc.checkForUpdate();
    expect(result, isFalse);
    expect(svc.current.stage, UpdateStage.failed);
    expect(svc.current.error, contains('offline'));
    svc.dispose();
  });

  test('download → ready transitions without installer handoff', () async {
    final svc = UpdateService(
      currentVersion: '0.48.0',
      channel: 'stable',
      baseUrl: 'https://example.com',
      fetchAppcast: (_) async => xmlWithUpdate,
    );
    await svc.checkForUpdate();
    await svc.downloadUpdate();
    expect(svc.current.stage, UpdateStage.ready);
    expect(svc.current.newVersion, '0.49.0');
    svc.dispose();
  });

  test('applyUpdate invokes handoffInstaller with download URL', () async {
    String? handedOff;
    final svc = UpdateService(
      currentVersion: '0.48.0',
      channel: 'stable',
      baseUrl: 'https://example.com',
      fetchAppcast: (_) async => xmlWithUpdate,
      handoffInstaller: (url) async {
        handedOff = url;
      },
    );
    await svc.checkForUpdate();
    await svc.downloadUpdate();
    await svc.applyUpdate();
    expect(handedOff, 'https://termex.app/dl/Termex-0.49.0.dmg');
    svc.dispose();
  });

  test('fetchAppcast receives channel-aware URL', () async {
    String? requested;
    final svc = UpdateService(
      currentVersion: '0.48.0',
      channel: 'beta',
      baseUrl: 'https://termex.app/updates',
      fetchAppcast: (url) async {
        requested = url;
        return xmlNoUpdate;
      },
    );
    await svc.checkForUpdate();
    expect(requested, 'https://termex.app/updates/beta/appcast.xml');
    svc.dispose();
  });

  test('downloadUpdate throws when no pending', () async {
    final svc = UpdateService(
      currentVersion: '0.49.0',
      channel: 'stable',
      baseUrl: 'https://x.com',
      fetchAppcast: (_) async => xmlNoUpdate,
    );
    expect(() => svc.downloadUpdate(), throwsStateError);
    svc.dispose();
  });
}
