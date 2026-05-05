import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:termex/features/monitor/state/monitor_provider.dart';

ProviderContainer _container() => ProviderContainer();

void main() {
  group('MonitorNotifier', () {
    test('initial state is empty', () {
      final c = _container();
      addTearDown(c.dispose);
      final s = c.read(monitorProvider);
      expect(s.stats, isNull);
      expect(s.processes, isEmpty);
      expect(s.isPolling, isFalse);
      expect(s.isLoading, isFalse);
    });

    test('startPolling sets isPolling true', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(monitorProvider.notifier).startPolling('sess-1');
      expect(c.read(monitorProvider).isPolling, isTrue);
      c.read(monitorProvider.notifier).stopPolling();
    });

    test('stopPolling clears isPolling', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(monitorProvider.notifier).startPolling('sess-1');
      c.read(monitorProvider.notifier).stopPolling();
      expect(c.read(monitorProvider).isPolling, isFalse);
    });

    test('startPolling populates stats after first tick', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(monitorProvider.notifier).startPolling('sess-1');
      expect(c.read(monitorProvider).stats, isNotNull);
      c.read(monitorProvider.notifier).stopPolling();
    });

    test('history grows after polling starts', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(monitorProvider.notifier).startPolling('sess-1');
      // First tick happens synchronously inside startPolling.
      expect(c.read(monitorProvider).history, isNotEmpty);
      c.read(monitorProvider.notifier).stopPolling();
    });

    test('sendSignal with valid signal clears error', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(monitorProvider.notifier).sendSignal('s', 1234, 'SIGTERM');
      expect(c.read(monitorProvider).error, isNull);
    });

    test('sendSignal with invalid signal sets error', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(monitorProvider.notifier).sendSignal('s', 1234, 'SIGFOO');
      expect(c.read(monitorProvider).error, contains('Unsupported'));
    });

    test('refreshProcesses sets isLoading then clears', () async {
      final c = _container();
      addTearDown(c.dispose);
      await c.read(monitorProvider.notifier).refreshProcesses('sess-1');
      final s = c.read(monitorProvider);
      expect(s.isLoading, isFalse);
      expect(s.processes, isEmpty);
    });

    test('SystemStats.zero returns all-zero stats', () {
      final s = SystemStats.zero();
      expect(s.cpuPercent, equals(0.0));
      expect(s.memUsedMb, equals(0));
      expect(s.memPercent, equals(0.0));
      expect(s.diskPercent, equals(0.0));
    });
  });
}

