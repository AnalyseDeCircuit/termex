import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens.dart';
import '../state/local_ai_provider.dart';
import 'model_card.dart';

/// Scrollable list of all available local AI models.
class ModelList extends ConsumerWidget {
  const ModelList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(localAiProvider).models;

    if (models.isEmpty) {
      return Center(
        child: Text(
          '正在加载模型列表…',
          style: TextStyle(fontSize: 13, color: TermexColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: models.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => ModelCard(model: models[i]),
    );
  }
}
