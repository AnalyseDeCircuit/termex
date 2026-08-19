import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/ai/state/local_ai_provider.dart';

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

    // The catalogue lives in Rust, keyed by the ids the files on disk are
    // named after. Dart used to carry two invented entries as a fallback —
    // 'llama-3-8b' and 'qwen-2-7b', which matched neither the bridge nor any
    // file — so downloading one failed with "unknown model id".
    test('no models are invented when the bridge is unavailable', () {
      expect(container.read(localAiProvider).models, isEmpty);
    });

    test('no download progress initially', () {
      final models = container.read(localAiProvider).models;
      expect(models.every((m) => m.downloadProgress == null), isTrue);
    });

    test('startServer transitions through starting → running', () async {
      final notifier = container.read(localAiProvider.notifier);

      // Mark model as downloaded for test purposes (internal helper)
      // We verify state transitions indirectly via the stub behavior.
      await notifier.startServer('qwen2.5-7b-q4');

      final state = container.read(localAiProvider);
      // Stub immediately transitions to running
      expect(state.status, LocalAiStatus.running);
      expect(state.loadedModelId, 'qwen2.5-7b-q4');
    });

    test('stopServer resets status to stopped', () async {
      final notifier = container.read(localAiProvider.notifier);
      await notifier.startServer('qwen2.5-7b-q4');
      await notifier.stopServer();
      final state = container.read(localAiProvider);
      expect(state.status, LocalAiStatus.stopped);
      expect(state.loadedModelId, isNull);
    });
  });
}
