import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens.dart';
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLoaded ? TermexColors.primary : TermexColors.border,
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
                        color: TermexColors.textPrimary,
                      ),
                    ),
                    Text(
                      model.quantization,
                      style: TextStyle(
                          fontSize: 10, color: TermexColors.textSecondary),
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
                    color: TermexColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '运行中',
                    style: TextStyle(
                        fontSize: 10, color: TermexColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            model.description,
            style:
                TextStyle(fontSize: 11, color: TermexColors.textSecondary),
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
                      label: '启动',
                      icon: Icons.play_arrow_rounded,
                      onTap: () => notifier.startServer(model.id),
                    ),
                  const SizedBox(width: 8),
                  _Action(
                    label: '删除',
                    icon: Icons.delete_outline,
                    danger: true,
                    onTap: () async {
                      final ok = await _confirmDelete(context, model.name);
                      if (ok) notifier.deleteModel(model.id);
                    },
                  ),
                ] else
                  _Action(
                    label: '下载 (${model.sizeLabel})',
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
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: TermexColors.backgroundSecondary,
            title: Text('删除模型',
                style: TextStyle(color: TermexColors.textPrimary, fontSize: 14)),
            content: Text('确定要删除 $name 吗？',
                style: TextStyle(color: TermexColors.textSecondary, fontSize: 13)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('取消',
                    style: TextStyle(color: TermexColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    Text('删除', style: TextStyle(color: TermexColors.danger)),
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
        color: TermexColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: TermexColors.textSecondary)),
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
    final color = danger ? TermexColors.danger : TermexColors.primary;
    return GestureDetector(
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
