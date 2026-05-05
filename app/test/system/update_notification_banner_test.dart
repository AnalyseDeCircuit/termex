import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:termex/system/update_notification_banner.dart';
import 'package:termex/system/update_service.dart';
import 'package:termex/system/state/update_provider.dart';

const _xmlWithUpdate = '''
  <rss><channel><item>
    <sparkle:version>0.49.0</sparkle:version>
    <enclosure url="u" length="1"/>
  </item></channel></rss>''';

UpdateService _svc(String xml) => UpdateService(
      currentVersion: '0.48.0',
      channel: 'stable',
      baseUrl: 'https://termex.app/updates',
      fetchAppcast: (_) async => xml,
    );

Widget _wrap(UpdateService svc, {VoidCallback? onTap}) => ProviderScope(
      overrides: [updateServiceProvider.overrideWithValue(svc)],
      child: MaterialApp(
        home: Scaffold(
          body: UpdateNotificationBanner(onOpenSettings: onTap),
        ),
      ),
    );

void main() {
  testWidgets('hidden when no update', (tester) async {
    final svc = _svc('<rss><channel></channel></rss>');
    addTearDown(svc.dispose);
    await tester.pumpWidget(_wrap(svc));
    await tester.pump();
    expect(find.textContaining('有可用更新'), findsNothing);
    expect(find.textContaining('重启'), findsNothing);
  });

  testWidgets('shows available badge after check', (tester) async {
    final svc = _svc(_xmlWithUpdate);
    addTearDown(svc.dispose);
    await tester.pumpWidget(_wrap(svc));
    await svc.checkForUpdate();
    await tester.pump();
    expect(find.textContaining('有可用更新 v0.49.0'), findsOneWidget);
  });

  testWidgets('tap invokes onOpenSettings', (tester) async {
    final svc = _svc(_xmlWithUpdate);
    addTearDown(svc.dispose);
    var tapped = 0;
    await tester.pumpWidget(_wrap(svc, onTap: () => tapped++));
    await svc.checkForUpdate();
    await tester.pump();

    await tester.tap(find.byType(UpdateNotificationBanner));
    expect(tapped, 1);
  });
}
