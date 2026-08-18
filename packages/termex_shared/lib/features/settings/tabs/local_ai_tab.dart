/// Local AI settings tab — port / threads / context size + the embedded
/// LocalAiPanel from v0.45.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../ai/local_ai/local_ai_panel.dart';
import '../state/settings_provider.dart';
import '../widgets/setting_row.dart';

class LocalAiTab extends ConsumerWidget {
  const LocalAiTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).settings;
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SettingRow(
          label: l10n.settingsAiServerPort,
          child: _numberField(
            context,
            value: settings.localAiPort,
            onChanged: (v) =>
                notifier.update(settings.copyWith(localAiPort: v)),
          ),
        ),
        SettingRow(
          label: l10n.settingsAiInferenceThreads,
          child: _numberField(
            context,
            value: settings.localAiThreads,
            onChanged: (v) =>
                notifier.update(settings.copyWith(localAiThreads: v)),
          ),
        ),
        SettingRow(
          label: l10n.settingsLocalAiContextSize,
          hint: l10n.settingsLocalAiContextSizeHint,
          child: _numberField(
            context,
            value: settings.localAiContextSize,
            onChanged: (v) =>
                notifier.update(settings.copyWith(localAiContextSize: v)),
          ),
        ),
        const Divider(height: 32),
        Text(
          l10n.settingsLocalAiModelManagement,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 400, child: LocalAiPanel()),
      ],
    );
  }

  Widget _numberField(
    BuildContext context, {
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final controller = TextEditingController(text: '$value');
    return SizedBox(
      width: 120,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onSubmitted: (s) {
          final v = int.tryParse(s);
          if (v != null && v > 0) onChanged(v);
        },
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
      ),
    );
  }
}
