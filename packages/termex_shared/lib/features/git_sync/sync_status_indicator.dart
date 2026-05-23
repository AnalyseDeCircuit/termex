/// Compact Git Sync status indicator shown next to a server tab title.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import 'state/git_sync_provider.dart';

class SyncStatusIndicator extends ConsumerWidget {
  final String serverId;
  final double size;

  const SyncStatusIndicator({
    super.key,
    required this.serverId,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(gitSyncStatusProvider(serverId));
    if (!status.enabled) {
      return const SizedBox.shrink();
    }
    final color = _colorFor(status.health);
    return Tooltip(
      message: status.health.label +
          (status.lastSyncAt != null
              ? '\n最近同步: ${status.lastSyncAt!}'
              : ''),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(GitSyncHealth h) {
    return switch (h) {
      GitSyncHealth.synced => Colors.green,
      GitSyncHealth.pushing => Colors.amber,
      GitSyncHealth.pulling => Colors.amber,
      GitSyncHealth.conflict => Colors.red,
      GitSyncHealth.error => Colors.red,
      GitSyncHealth.disabled => TermexColors.textSecondary,
    };
  }
}
