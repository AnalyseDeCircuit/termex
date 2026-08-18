import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/clickable.dart';
import '../state/local_ai_provider.dart';
import 'download_progress.dart';

/// Card displaying a single local AI model with download / start / delete actions.
class ModelCard extends ConsumerWidget {
  final LocalModel model;

  const ModelCard({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(localAiProvider.notifier);
    final aiState = ref.watch(localAiProvider);
    final isLoaded = aiState.loadedModelId == model.id;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLoaded ? context.colors.primary : context.colors.border,
          width: isLoaded ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      model.quantization,
                      style: TextStyle(
                          fontSize: 10, color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              _SizeChip(label: model.sizeLabel),
              const SizedBox(width: 8),
              if (isLoaded)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.localAiRunning,
                    style: TextStyle(
                        fontSize: 10, color: context.colors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            model.description,
            style:
                TextStyle(fontSize: 11, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 8),

          // Download progress
          if (model.downloadProgress != null)
            ModelDownloadProgress(
              model: model,
              onCancel: () => notifier.cancelDownload(model.id),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (model.isDownloaded) ...[
                  if (!isLoaded)
                    _Action(
                      label: l10n.localAiStart,
                      icon: Icons.play_arrow_rounded,
                      onTap: () => notifier.startServer(model.id),
                    ),
                  const SizedBox(width: 8),
                  _Action(
                    label: l10n.commonDelete,
                    icon: Icons.delete_outline,
                    danger: true,
                    onTap: () async {
                      final ok = await _confirmDelete(context, model.name);
                      if (ok) notifier.deleteModel(model.id);
                    },
                  ),
                ] else
                  _Action(
                    label: l10n.localAiDownloadWithSize(model.sizeLabel),
                    icon: Icons.download_rounded,
                    onTap: () => notifier.downloadModel(model.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: context.colors.backgroundSecondary,
            title: Text(l10n.aiDeleteModelTitle,
                style: TextStyle(
                    color: context.colors.textPrimary, fontSize: 14)),
            content: Text(l10n.aiDeleteModelConfirm(name),
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 13)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.commonCancel,
                    style: TextStyle(color: context.colors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.commonDelete,
                    style: TextStyle(color: context.colors.danger)),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _SizeChip extends StatelessWidget {
  final String label;
  const _SizeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.backgroundTertiary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: context.colors.textSecondary)),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.colors.danger : context.colors.primary;
    return Clickable(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
