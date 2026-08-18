/// Embedded local-model picker used inside the inline AI provider form.
/// Lists every model in the catalog with radio selection (only enabled if
/// downloaded), inline download / cancel / retry / delete actions, and a
/// download progress bar — mirroring the Vue AiConfigTab layout.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/clickable.dart';
import '../state/local_ai_provider.dart';

class LocalModelPicker extends ConsumerWidget {
  final String selectedModelId;
  final ValueChanged<String> onSelected;

  const LocalModelPicker({
    super.key,
    required this.selectedModelId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(localAiProvider).models;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      constraints: const BoxConstraints(maxHeight: 240),
      child: models.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.aiModelListLoading,
                style: TextStyle(
                    fontSize: 12, color: context.colors.textSecondary),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: models.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: context.colors.border),
              itemBuilder: (_, i) => _ModelRow(
                model: models[i],
                isSelected: models[i].id == selectedModelId,
                onSelect: () => onSelected(models[i].id),
              ),
            ),
    );
  }
}

class _ModelRow extends ConsumerWidget {
  final LocalModel model;
  final bool isSelected;
  final VoidCallback onSelect;

  const _ModelRow({
    required this.model,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(localAiProvider.notifier);
    final canSelect = model.isDownloaded;
    final isDownloading = model.downloadProgress != null;

    return InkWell(
      onTap: canSelect ? onSelect : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            _Radio(selected: isSelected, enabled: canSelect),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    model.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: canSelect
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    '${model.sizeLabel} · ${model.quantization}',
                    style: TextStyle(
                        fontSize: 10, color: context.colors.textSecondary),
                  ),
                  if (isDownloading) ...[
                    const SizedBox(height: 4),
                    _ProgressBar(progress: model.downloadProgress ?? 0.0),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusAction(
              model: model,
              onDownload: () => notifier.downloadModel(model.id),
              onCancel: () => notifier.cancelDownload(model.id),
              onDelete: () async {
                final ok = await _confirmDelete(context, model.name);
                if (ok) notifier.deleteModel(model.id);
              },
            ),
          ],
        ),
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

class _Radio extends StatelessWidget {
  final bool selected;
  final bool enabled;
  const _Radio({required this.selected, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? context.colors.border
        : (selected
            ? context.colors.primary
            : context.colors.textSecondary);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      enabled ? context.colors.primary : context.colors.border,
                ),
              ),
            )
          : null,
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 3,
        backgroundColor: context.colors.backgroundTertiary,
        valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
      ),
    );
  }
}

class _StatusAction extends StatelessWidget {
  final LocalModel model;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _StatusAction({
    required this.model,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = model.downloadProgress != null;
    if (isDownloading) {
      final pct = ((model.downloadProgress ?? 0) * 100).toStringAsFixed(0);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$pct%',
              style: TextStyle(
                  fontSize: 10, color: context.colors.textSecondary)),
          const SizedBox(width: 6),
          _IconBtn(
            icon: Icons.close,
            color: context.colors.danger,
            onTap: onCancel,
          ),
        ],
      );
    }
    if (model.isDownloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle,
              size: 12, color: context.colors.success),
          const SizedBox(width: 4),
          _IconBtn(
            icon: Icons.delete_outline,
            color: context.colors.danger,
            onTap: onDelete,
          ),
        ],
      );
    }
    return _TextBtn(
      label: AppLocalizations.of(context).localAiDownload,
      icon: Icons.download_rounded,
      onTap: onDownload,
    );
  }
}

class _TextBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _TextBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.colors.primary),
          const SizedBox(width: 3),
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: context.colors.primary)),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }
}
