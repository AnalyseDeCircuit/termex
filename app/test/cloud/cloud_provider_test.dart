import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:termex/features/cloud/state/cloud_provider.dart';

void main() {
  group('CloudNotifier', () {
    test('initial state is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(cloudProvider);
      expect(state.k8sContexts, isEmpty);
      expect(state.ssmInstances, isEmpty);
      expect(state.ecsFavorites, isEmpty);
      expect(state.k8sPods, isEmpty);
    });

    test('loadK8sContexts populates contexts', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(cloudProvider.notifier).loadK8sContexts();
      final contexts = container.read(cloudProvider).k8sContexts;
      expect(contexts, isNotEmpty);
      expect(contexts.any((c) => c.isActive), isTrue);
    });

    test('switchContext updates active', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(cloudProvider.notifier).loadK8sContexts();
      final contexts = container.read(cloudProvider).k8sContexts;
      final second = contexts.firstWhere((c) => !c.isActive);
      await container.read(cloudProvider.notifier).switchContext(second.name);
      final updated = container.read(cloudProvider).k8sContexts;
      expect(updated.firstWhere((c) => c.name == second.name).isActive, isTrue);
      expect(updated.where((c) => c.isActive).length, equals(1));
    });

    test('loadPods populates pods list', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(cloudProvider.notifier).loadPods('prod-cluster', 'default');
      expect(container.read(cloudProvider).k8sPods, isNotEmpty);
    });

    test('loadSsmInstances populates instances', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(cloudProvider.notifier).loadSsmInstances();
      expect(container.read(cloudProvider).ssmInstances, isNotEmpty);
    });

    test('loadEcsFavorites populates favorites', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(cloudProvider.notifier).loadEcsFavorites();
      expect(container.read(cloudProvider).ecsFavorites, isNotEmpty);
    });

    test('addEcsFavorite increases count', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(cloudProvider.notifier).addEcsFavorite('i-1', 'Test', 'us-east-1', '1.2.3.4');
      expect(container.read(cloudProvider).ecsFavorites.length, equals(1));
    });

    test('removeEcsFavorite decreases count', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(cloudProvider.notifier).addEcsFavorite('i-1', 'Test', 'us-east-1', '1.2.3.4');
      final id = container.read(cloudProvider).ecsFavorites.first.id;
      await container.read(cloudProvider.notifier).removeEcsFavorite(id);
      expect(container.read(cloudProvider).ecsFavorites, isEmpty);
    });
  });
}
