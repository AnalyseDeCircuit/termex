import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../state/ai_stream_provider.dart';
import 'error_detector.dart';

/// Bottom sheet showing detected errors with one-tap AI diagnosis.
class DiagnoseSheet extends ConsumerWidget {
  final List<DetectedError> errors;
  final String? terminalContext;

  const DiagnoseSheet({
    super.key,
    required this.errors,
    this.terminalContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.25,
      maxChildSize: 0.75,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: TermexColors.backgroundSecondary,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(top: BorderSide(color: TermexColors.border)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TermexColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.bug_report_outlined,
                      size: 16, color: TermexColors.danger),
                  const SizedBox(width: 6),
                  Text(
                    '检测到 ${errors.length} 个错误',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TermexColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: errors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _ErrorCard(
                  error: errors[i],
                  onDiagnose: () async {
                    Navigator.of(context).pop();
                    if (errors[i].suggestedQuery != null) {
                      await ref.read(aiStreamProvider.notifier).send(
                            userContent: errors[i].suggestedQuery!,
                            terminalContext: terminalContext,
                          );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final DetectedError error;
  final VoidCallback onDiagnose;

  const _ErrorCard({required this.error, required this.onDiagnose});

  @override
  Widget build(BuildContext context) {
    final color = switch (error.severity) {
      ErrorSeverity.critical => TermexColors.danger,
      ErrorSeverity.error => TermexColors.danger.withOpacity(0.8),
      ErrorSeverity.warning => TermexColors.warning,
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error.rawLine,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: TermexColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDiagnose,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TermexColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'AI 诊断',
                style: TextStyle(
                  fontSize: 11,
                  color: TermexColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Show the diagnose sheet as a modal bottom sheet.
Future<void> showDiagnoseSheet(
  BuildContext context, {
  required List<DetectedError> errors,
  String? terminalContext,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DiagnoseSheet(
      errors: errors,
      terminalContext: terminalContext,
    ),
  );
}
