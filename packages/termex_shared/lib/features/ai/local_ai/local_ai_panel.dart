/// Local AI management panel — model list, download, and server control.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens.dart';
import '../state/local_ai_provider.dart';
import 'model_list.dart';
import 'server_status.dart';

class LocalAiPanel extends ConsumerWidget {
  const LocalAiPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localAiProvider);

    return Container(
      color: context.colors.backgroundPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.colors.backgroundSecondary,
              border:
                  Border(bottom: BorderSide(color: context.colors.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology_outlined,
                    size: 14, color: context.colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Local AI 模型',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Server status
          const LocalAiServerStatus(),

          // Error banner
          if (state.errorMessage != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: context.colors.danger.withOpacity(0.08),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 13, color: context.colors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(
                          fontSize: 11, color: context.colors.danger),
                    ),
                  ),
                ],
              ),
            ),

          // Model list
          const Expanded(child: ModelList()),
        ],
      ),
    );
  }
}
