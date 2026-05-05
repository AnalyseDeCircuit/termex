import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:termex/features/port_forward/state/port_forward_provider.dart';

ProviderContainer _container() => ProviderContainer();

void main() {
  group('PortForwardNotifier', () {
    test('initial state is empty', () {
      final c = _container();
      addTearDown(c.dispose);
      final s = c.read(portForwardProvider);
      expect(s.rules, isEmpty);
      expect(s.isLoading, isFalse);
      expect(s.error, isNull);
    });

    test('loadRules returns empty list', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(portForwardProvider.notifier).loadRules('sess-1');
      final s = c.read(portForwardProvider);
      expect(s.isLoading, isFalse);
      expect(s.rules, isEmpty);
    });

    test('addRule creates a rule with correct fields', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(portForwardProvider.notifier).addRule(
            sessionId: 'sess-1',
            forwardType: ForwardType.local,
            localPort: 8080,
            remoteHost: 'localhost',
            remotePort: 80,
          );
      final rules = c.read(portForwardProvider).rules;
      expect(rules.length, equals(1));
      expect(rules.first.forwardType, equals(ForwardType.local));
      expect(rules.first.localPort, equals(8080));
      expect(rules.first.remoteHost, equals('localhost'));
      expect(rules.first.remotePort, equals(80));
      expect(rules.first.isActive, isTrue);
    });

    test('addRule for dynamic type creates SOCKS5 rule', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(portForwardProvider.notifier).addRule(
            sessionId: 'sess-1',
            forwardType: ForwardType.dynamic,
            localPort: 1080,
            remoteHost: '',
            remotePort: 0,
          );
      final rules = c.read(portForwardProvider).rules;
      expect(rules.first.forwardType, equals(ForwardType.dynamic));
    });

    test('removeRule deletes the correct rule', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(portForwardProvider.notifier).addRule(
            sessionId: 'sess-1',
            forwardType: ForwardType.local,
            localPort: 3000,
            remoteHost: 'db',
            remotePort: 5432,
          );
      final id = c.read(portForwardProvider).rules.first.id;
      await c.read(portForwardProvider.notifier).removeRule(id);
      expect(c.read(portForwardProvider).rules, isEmpty);
    });

    test('multiple rules coexist', () async {
      final c = _container();
      addTearDown(c.dispose);
      final n = c.read(portForwardProvider.notifier);
      await n.addRule(
          sessionId: 's', forwardType: ForwardType.local,
          localPort: 8080, remoteHost: 'h', remotePort: 80);
      await n.addRule(
          sessionId: 's', forwardType: ForwardType.remote,
          localPort: 9090, remoteHost: 'h', remotePort: 9090);
      expect(c.read(portForwardProvider).rules.length, equals(2));
    });

    test('ForwardType.label extension returns readable text', () {
      expect(ForwardType.local.label, equals('Local'));
      expect(ForwardType.remote.label, equals('Remote'));
      expect(ForwardType.dynamic.label, contains('SOCKS5'));
    });

    test('ForwardRule.summary for local type', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(portForwardProvider.notifier).addRule(
            sessionId: 's',
            forwardType: ForwardType.local,
            localPort: 8080,
            remoteHost: 'remote.host',
            remotePort: 80,
          );
      final rule = c.read(portForwardProvider).rules.first;
      expect(rule.summary, contains('8080'));
      expect(rule.summary, contains('remote.host'));
    });
  });
}
