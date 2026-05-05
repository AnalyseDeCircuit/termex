/// Top-bar update notification banner (v0.49 spec §5.4).
///
/// Rendered in the shell status bar.  Only visible when an update is
/// available or ready.  Click to jump to the About settings tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import 'auto_updater.dart';
import 'state/update_provider.dart';

class UpdateNotificationBanner extends ConsumerWidget {
  final VoidCallback? onOpenSettings;

  const UpdateNotificationBanner({super.key, this.onOpenSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(updateStatusProvider);
    final status = statusAsync.when(
      data: (s) => s,
      loading: () => const UpdateStatus.idle(),
      error: (_, __) => const UpdateStatus.idle(),
    );

    final visible = status.stage == UpdateStage.available ||
        status.stage == UpdateStage.ready;
    if (!visible) return const SizedBox.shrink();

    final color = status.stage == UpdateStage.ready
        ? TermexColors.success
        : TermexColors.primary;
    final label = status.stage == UpdateStage.ready
        ? '更新已就绪 v${status.newVersion ?? ""} — 点击重启'
        : '有可用更新 v${status.newVersion ?? ""}';
    final icon = status.stage == UpdateStage.ready
        ? Icons.download_done
        : Icons.new_releases;

    return GestureDetector(
      onTap: onOpenSettings,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
