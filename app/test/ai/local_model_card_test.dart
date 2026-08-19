import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/ai/local_ai/model_card.dart';
import 'package:termex_shared/features/ai/state/local_ai_provider.dart';
import 'package:termex_shared/l10n/app_localizations.dart';

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

const _catalogued = LocalModel(
  id: 'qwen2.5-7b-q4',
  name: 'Qwen2.5 7B',
  description: 'Best quality.',
  sizeBytes: 5046586573,
  sizeLabel: '4.7 GB',
  quantization: 'Q4_K_M',
  tier: 'large',
  minRamGb: 16,
  contextLength: 32768,
  recommended: true,
);

void main() {
  group('ModelCard', () {
    // The Tauri list showed the RAM requirement and context window; the port
    // dropped both, leaving no way to tell whether a model would fit.
    testWidgets('shows the RAM requirement and context window',
        (tester) async {
      await tester.pumpWidget(_host(const ModelCard(model: _catalogued)));
      await tester.pump();

      expect(find.textContaining('16'), findsWidgets);
      expect(find.textContaining('32K'), findsOneWidget,
          reason: 'context window should be abbreviated, not raw');
    });

    testWidgets('marks the recommended entry', (tester) async {
      await tester.pumpWidget(_host(const ModelCard(model: _catalogued)));
      await tester.pump();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(ModelCard)));
      expect(find.text(l10n.localAiRecommended), findsOneWidget);
    });

    // A file found on disk under an id no catalogue entry describes has no
    // URL behind it — offering "download" would be a dead button.
    testWidgets('an adopted model offers start and delete, not download',
        (tester) async {
      const adopted = LocalModel(
        id: 'some-retired-model-q5',
        name: 'some-retired-model-q5',
        description: '',
        sizeBytes: 1234,
        sizeLabel: '1.2 GB',
        quantization: '',
        isDownloaded: true,
        isAdopted: true,
      );
      await tester.pumpWidget(_host(const ModelCard(model: adopted)));
      await tester.pump();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(ModelCard)));
      expect(find.text(l10n.localAiStart), findsOneWidget);
      expect(find.text(l10n.commonDelete), findsOneWidget);
      expect(find.text(l10n.localAiDownloadWithSize('1.2 GB')), findsNothing);
      expect(find.text(l10n.localAiAdoptedModel), findsOneWidget);
    });

    testWidgets('a catalogued model that is not on disk offers download',
        (tester) async {
      await tester.pumpWidget(_host(const ModelCard(model: _catalogued)));
      await tester.pump();

      final l10n =
          AppLocalizations.of(tester.element(find.byType(ModelCard)));
      expect(find.text(l10n.localAiDownloadWithSize('4.7 GB')), findsOneWidget);
    });
  });
}
