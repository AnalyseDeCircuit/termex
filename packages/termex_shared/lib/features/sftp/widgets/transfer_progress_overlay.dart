/// Transfer progress overlay — floats above the SFTP panel.
///
/// Shows a compact list of active transfers with progress bars.
/// Completed transfers fade out and can be cleared with one tap.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/clickable.dart';
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
            color: context.colors.backgroundSecondary,
            border: Border.all(color: context.colors.border),
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
              Divider(height: 1, color: context.colors.border),
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
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(l10n.sftpTransfers,
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          const Spacer(),
          if (hasCompleted)
            Clickable(
              onTap: onClear,
              child: Text(l10n.sftpClearCompleted,
                  style: TextStyle(
                      color: context.colors.textMuted, fontSize: 11)),
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
    final l10n = AppLocalizations.of(context);
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
                  ? context.colors.primary
                  : context.colors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  style: TextStyle(
                      fontSize: 12, color: context.colors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (isActive)
                  LinearProgressIndicator(
                    value: item.progress,
                    backgroundColor: context.colors.border,
                    color: context.colors.primary,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                  )
                else
                  Text(
                    _statusLabel(l10n, item.status, item.errorMessage),
                    style: TextStyle(
                        fontSize: 10,
                        color: _statusColor(item.status, context.colors)),
                  ),
              ],
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 8),
            if (item.status == TransferStatus.paused)
              _IconBtn(
                icon: Icons.play_arrow,
                tooltip: l10n.sftpTransferResume,
                color: context.colors.success,
                onTap: () => ref
                    .read(sftpTransferProvider(sessionId).notifier)
                    .resume(item.id),
              )
            else
              _IconBtn(
                icon: Icons.pause,
                tooltip: l10n.sftpTransferPause,
                color: context.colors.warning,
                onTap: () => ref
                    .read(sftpTransferProvider(sessionId).notifier)
                    .pause(item.id),
              ),
            const SizedBox(width: 4),
            _IconBtn(
              icon: Icons.close,
              tooltip: l10n.sftpCancel,
              color: context.colors.textMuted,
              onTap: () => ref
                  .read(sftpTransferProvider(sessionId).notifier)
                  .cancel(item.id),
            ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(
      AppLocalizations l10n, TransferStatus s, String? error) {
    return switch (s) {
      TransferStatus.completed => l10n.sftpTransferDone,
      TransferStatus.failed => l10n.sftpTransferFailed(error ?? ''),
      TransferStatus.cancelled => l10n.sftpTransferCancelled,
      TransferStatus.paused => l10n.sftpTransferPaused,
      _ => '',
    };
  }

  static Color _statusColor(TransferStatus s, TermexColorScheme colors) {
    return switch (s) {
      TransferStatus.completed => colors.success,
      TransferStatus.failed => colors.danger,
      TransferStatus.cancelled => colors.textMuted,
      TransferStatus.paused => colors.warning,
      _ => colors.textSecondary,
    };
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Clickable(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 18,
          height: 18,
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}
