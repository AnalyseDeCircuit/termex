import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:termex/features/proxy/state/proxy_provider.dart';

ProviderContainer _container() => ProviderContainer();

void main() {
  group('ProxyNotifier', () {
    test('initial state is empty', () {
      final c = _container();
      addTearDown(c.dispose);
      final s = c.read(proxyProvider);
      expect(s.proxies, isEmpty);
      expect(s.isLoading, isFalse);
      expect(s.error, isNull);
      expect(s.defaultProxy, isNull);
    });

    test('loadProxies returns empty list', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(proxyProvider.notifier).loadProxies();
      final s = c.read(proxyProvider);
      expect(s.isLoading, isFalse);
      expect(s.proxies, isEmpty);
    });

    test('createProxy adds entry', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(proxyProvider.notifier).createProxy(
            proxyType: ProxyType.socks5,
            host: '127.0.0.1',
            port: 1080,
          );
      final proxies = c.read(proxyProvider).proxies;
      expect(proxies.length, equals(1));
      expect(proxies.first.proxyType, equals(ProxyType.socks5));
      expect(proxies.first.host, equals('127.0.0.1'));
      expect(proxies.first.port, equals(1080));
    });

    test('first proxy is set as default automatically', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(proxyProvider.notifier).createProxy(
            proxyType: ProxyType.http,
            host: 'proxy.local',
            port: 8080,
          );
      expect(c.read(proxyProvider).proxies.first.isDefault, isTrue);
    });

    test('second proxy is NOT auto-default when first exists', () async {
      final c = _container();
      addTearDown(c.dispose);
      final n = c.read(proxyProvider.notifier);
      await n.createProxy(proxyType: ProxyType.socks5, host: 'a', port: 1080);
      await n.createProxy(proxyType: ProxyType.http, host: 'b', port: 8080);
      final proxies = c.read(proxyProvider).proxies;
      expect(proxies.where((p) => p.isDefault).length, equals(1));
    });

    test('deleteProxy removes entry', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(proxyProvider.notifier).createProxy(
            proxyType: ProxyType.socks5,
            host: '127.0.0.1',
            port: 1080,
          );
      final id = c.read(proxyProvider).proxies.first.id;
      await c.read(proxyProvider.notifier).deleteProxy(id);
      expect(c.read(proxyProvider).proxies, isEmpty);
    });

    test('setDefault marks correct proxy', () async {
      final c = _container();
      addTearDown(c.dispose);
      final n = c.read(proxyProvider.notifier);
      await n.createProxy(proxyType: ProxyType.socks5, host: 'a', port: 1080);
      await n.createProxy(proxyType: ProxyType.http, host: 'b', port: 8080);
      final secondId = c.read(proxyProvider).proxies.last.id;
      await n.setDefault(secondId);
      expect(c.read(proxyProvider).defaultProxy?.id, equals(secondId));
    });

    test('setDefault clears previous default', () async {
      final c = _container();
      addTearDown(c.dispose);
      final n = c.read(proxyProvider.notifier);
      await n.createProxy(proxyType: ProxyType.socks5, host: 'a', port: 1080);
      await n.createProxy(proxyType: ProxyType.http, host: 'b', port: 8080);
      final secondId = c.read(proxyProvider).proxies.last.id;
      await n.setDefault(secondId);
      final proxies = c.read(proxyProvider).proxies;
      expect(proxies.where((p) => p.isDefault).length, equals(1));
    });

    test('testConnection sets error (stub behavior)', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(proxyProvider.notifier).createProxy(
            proxyType: ProxyType.socks5,
            host: '127.0.0.1',
            port: 1080,
          );
      final id = c.read(proxyProvider).proxies.first.id;
      await c.read(proxyProvider.notifier).testConnection(id);
      // Stub sets an error message and clears testingId.
      expect(c.read(proxyProvider).testingId, isNull);
      expect(c.read(proxyProvider).error, isNotNull);
    });

    test('ProxyType.label extension returns readable text', () {
      expect(ProxyType.socks5.label, equals('SOCKS5'));
      expect(ProxyType.http.label, equals('HTTP'));
      expect(ProxyType.tor.label, equals('Tor'));
    });

    test('ProxyConfig.address returns host:port', () {
      const p = ProxyConfig(
        id: 'x',
        proxyType: ProxyType.socks5,
        host: '10.0.0.1',
        port: 1080,
        isDefault: false,
      );
      expect(p.address, equals('10.0.0.1:1080'));
    });
  });
}
