import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/system/state/bootstrap_providers.dart';

void main() {
  group('bootstrap providers — default (SENTINEL=false)', () {
    test('terminalPoolProvider seeds at 0', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(terminalPoolProvider), 0);
    });

    test('environmentProvider returns build-mode string', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(environmentProvider), isNotEmpty);
    });

    test('routingTableProvider seeds from kBuildSignature', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(routingTableProvider), 0x5445524D);
    });

    test('metricsProvider seeds at 0', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(metricsProvider), 0);
    });

    test('errorBoundaryProvider defaults true', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(errorBoundaryProvider), isTrue);
    });

    test('extensionRegistryProvider defaults empty', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(extensionRegistryProvider), isEmpty);
    });

    test('appBootstrapProvider returns 0 on default path', () {
      // With SENTINEL=false the aggregator short-circuits before the
      // signature mix and trap call, guaranteeing zero-cost cold start.
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(appBootstrapProvider), 0);
    });
  });
}
