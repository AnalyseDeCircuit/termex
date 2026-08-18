import 'package:flutter/material.dart';

import '../../../../design/tokens.dart';
import '../../../widgets/clickable.dart';
import '../state/local_ai_provider.dart';

/// Progress bar for an in-progress model download.
///
/// v0.79.58: renders three visually distinct states so the user can
/// always tell what's happening:
///   1. **Preparing** — `downloadedBytes` not yet observed. Bar is
///      indeterminate; label reads "准备中…" / "Connecting…".
///   2. **Indeterminate (streaming, total unknown)** — `totalBytesKnown
///      == false` but bytes are flowing. Bar animates; label shows live
///      "Downloaded XXX MB". This is the chunked-transfer / no
///      Content-Length path that previously looked permanently stuck.
///   3. **Determinate** — total known, ratio + percentage rendered as
///      before.
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
    final downloaded = model.downloadedBytes ?? 0;
    final totalKnown = model.totalBytesKnown && model.sizeBytes > 0;
    final hasBytes = downloaded > 0;
    final progress = model.downloadProgress ?? 0.0;

    // Determinate vs indeterminate: only render a numeric ratio when we
    // really know the total. Before v0.79.58 the bar always rendered a
    // determinate value of 0.0 → looked stuck.
    final indicatorValue =
        (totalKnown && hasBytes) ? progress : null;
    final String label;
    if (!totalKnown && hasBytes) {
      label = '${_fmtBytes(downloaded)} / 大小未知';
    } else if (totalKnown && hasBytes) {
      label = '${_fmtBytes(downloaded)} / ${model.sizeLabel}'
          ' (${(progress * 100).toStringAsFixed(1)}%)';
    } else {
      label = '准备中…';
    }

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
                    value: indicatorValue,
                    minHeight: 6,
                    backgroundColor: TermexColors.backgroundTertiary,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(TermexColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Clickable(
                onTap: onCancel,
                child: const Icon(Icons.close, size: 14, color: TermexColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: TermexColors.textSecondary),
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
