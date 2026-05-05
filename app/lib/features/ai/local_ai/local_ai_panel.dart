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
      color: TermexColors.backgroundPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: TermexColors.backgroundSecondary,
              border:
                  Border(bottom: BorderSide(color: TermexColors.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology_outlined,
                    size: 14, color: TermexColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Local AI 模型',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TermexColors.textPrimary,
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
              color: TermexColors.danger.withOpacity(0.08),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 13, color: TermexColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(
                          fontSize: 11, color: TermexColors.danger),
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
