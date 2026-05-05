/// Transfer progress overlay — floats above the SFTP panel.
///
/// Shows a compact list of active transfers with progress bars.
/// Completed transfers fade out and can be cleared with one tap.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../state/sftp_transfer_provider.dart';

/// Renders a floating panel of in-progress and recent transfers.
///
/// Mount inside a [Stack]; it auto-hides when there are no transfers.
class TransferProgressOverlay extends ConsumerWidget {
  final String sessionId;

  const TransferProgressOverlay({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sftpTransferProvider(sessionId));
    if (state.items.isEmpty) return const SizedBox.shrink();

    return Positioned(
      right: 12,
      bottom: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          decoration: BoxDecoration(
            color: TermexColors.backgroundSecondary,
            border: Border.all(color: TermexColors.border),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 10),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(
                  hasCompleted: state.completed.isNotEmpty,
                  onClear: () => ref
                      .read(sftpTransferProvider(sessionId).notifier)
                      .clearCompleted()),
              const Divider(height: 1, color: TermexColors.border),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final item in state.active) _TransferRow(item: item, sessionId: sessionId),
                    for (final item in state.completed)
                      _TransferRow(item: item, sessionId: sessionId),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool hasCompleted;
  final VoidCallback onClear;

  const _Header({required this.hasCompleted, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Text('传输',
              style: TextStyle(
                  color: TermexColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          const Spacer(),
          if (hasCompleted)
            GestureDetector(
              onTap: onClear,
              child: const Text('清除已完成',
                  style: TextStyle(
                      color: TermexColors.textMuted, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

class _TransferRow extends ConsumerWidget {
  final TransferItem item;
  final String sessionId;

  const _TransferRow({required this.item, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = !item.isDone;
    final icon = item.direction == TransferDirection.upload
        ? Icons.upload_outlined
        : Icons.download_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 15,
              color: isActive
                  ? TermexColors.primary
                  : TermexColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  style: const TextStyle(
                      fontSize: 12, color: TermexColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (isActive)
                  LinearProgressIndicator(
                    value: item.progress,
                    backgroundColor: TermexColors.border,
                    color: TermexColors.primary,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                  )
                else
                  Text(
                    _statusLabel(item.status, item.errorMessage),
                    style: TextStyle(
                        fontSize: 10,
                        color: _statusColor(item.status)),
                  ),
              ],
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => ref
                  .read(sftpTransferProvider(sessionId).notifier)
                  .cancel(item.id),
              child: const Icon(Icons.close,
                  size: 14, color: TermexColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(TransferStatus s, String? error) {
    return switch (s) {
      TransferStatus.completed => '完成',
      TransferStatus.failed => '失败：${error ?? ''}',
      TransferStatus.cancelled => '已取消',
      _ => '',
    };
  }

  static Color _statusColor(TransferStatus s) {
    return switch (s) {
      TransferStatus.completed => TermexColors.success,
      TransferStatus.failed => TermexColors.danger,
      TransferStatus.cancelled => TermexColors.textMuted,
      _ => TermexColors.textSecondary,
    };
  }
}
