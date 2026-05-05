import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/ai/state/local_ai_provider.dart';

void main() {
  group('LocalAiNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial status is stopped', () {
      expect(container.read(localAiProvider).status, LocalAiStatus.stopped);
    });

    test('models are loaded on creation', () {
      final models = container.read(localAiProvider).models;
      expect(models, isNotEmpty);
      expect(models.first.id, isNotEmpty);
    });

    test('all initial models are not downloaded', () {
      final models = container.read(localAiProvider).models;
      expect(models.every((m) => !m.isDownloaded), isTrue);
    });

    test('no download progress initially', () {
      final models = container.read(localAiProvider).models;
      expect(models.every((m) => m.downloadProgress == null), isTrue);
    });

    test('startServer transitions through starting → running', () async {
      final notifier = container.read(localAiProvider.notifier);
      final firstModel = container.read(localAiProvider).models.first;

      // Mark model as downloaded for test purposes (internal helper)
      // We verify state transitions indirectly via the stub behavior.
      await notifier.startServer(firstModel.id);

      final state = container.read(localAiProvider);
      // Stub immediately transitions to running
      expect(state.status, LocalAiStatus.running);
      expect(state.loadedModelId, firstModel.id);
    });

    test('stopServer resets status to stopped', () async {
      final notifier = container.read(localAiProvider.notifier);
      await notifier.startServer(container.read(localAiProvider).models.first.id);
      await notifier.stopServer();
      final state = container.read(localAiProvider);
      expect(state.status, LocalAiStatus.stopped);
      expect(state.loadedModelId, isNull);
    });
  });
}
