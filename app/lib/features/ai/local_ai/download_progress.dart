import 'package:flutter/material.dart';

import '../../../../design/tokens.dart';
import '../state/local_ai_provider.dart';

/// Progress bar for an in-progress model download.
class ModelDownloadProgress extends StatelessWidget {
  final LocalModel model;
  final VoidCallback onCancel;

  const ModelDownloadProgress({
    super.key,
    required this.model,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final progress = model.downloadProgress ?? 0.0;
    final received = (model.sizeBytes * progress).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: TermexColors.backgroundTertiary,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(TermexColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onCancel,
                child: Icon(Icons.close, size: 14, color: TermexColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${_fmtBytes(received)} / ${model.sizeLabel} (${(progress * 100).toStringAsFixed(1)}%)',
            style: TextStyle(fontSize: 10, color: TermexColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
