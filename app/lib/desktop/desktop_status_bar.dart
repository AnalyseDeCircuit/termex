import 'package:flutter/material.dart' show CircularProgressIndicator, Icons, Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/design/spacing.dart';
import 'package:termex_shared/design/typography.dart';
import 'package:termex_shared/features/port_forward/state/port_forward_provider.dart';
import 'package:termex_shared/features/server_list/state/connection_provider.dart';
import 'package:termex_shared/features/tabs/state/tab_controller.dart';
import 'package:termex_shared/system/auto_updater.dart';
import 'package:termex_shared/system/state/update_provider.dart';
import 'package:termex_shared/terminal/broadcast_registry.dart';
import 'package:termex_shared/terminal/features/tmux/tmux_provider.dart';
import 'state/desktop_shell_state.dart';

/// Bottom status bar — mirrors Tauri's StatusBar.vue with connection status,
/// port-forward badge, update dot, broadcast indicator, and encoding.
class DesktopStatusBar extends ConsumerWidget {
  const DesktopStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(activeTabIdProvider);
    final broadcast = ref.watch(broadcastRegistryProvider);
    final pfState = ref.watch(portForwardProvider);
    final updateAsync = ref.watch(updateStatusProvider);

    final (statusText, statusColor) = _statusFor(ref, activeId);
    final activeForwards = pfState.rules.where((r) => r.isActive).length;
    final hasUpdate = updateAsync.valueOrNull?.stage == UpdateStage.available;

    // P1.5: Tmux indicator — look up the active tab's session id and check
    // whether tmuxMode + heuristic detection mark it as attached.
    final activeSid = activeId == null
        ? null
        : ref.watch(connectionProvider(activeId).select((s) => s.sessionId));
    final isTmuxAttached = activeSid != null &&
        ref.watch(isTmuxAttachedProvider(activeSid));

    return Container(
      height: 22,
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(top: BorderSide(color: TermexColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: TermexSpacing.md),
      child: Row(
        children: [
          // Connection status
          _StatusDot(color: statusColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TermexTypography.caption.copyWith(
              color: TermexColors.textSecondary,
            ),
          ),
          const Spacer(),
          // Port forward badge
          if (activeForwards > 0) ...[
            Tooltip(
              message: '$activeForwards 条端口转发活跃 · 点击查看',
              child: GestureDetector(
                onTap: () => toggleDesktopSidePanel(ref, DesktopSidePanel.portForward),
                child: _StatusChip(
                  icon: Icons.swap_horiz,
                  label: '$activeForwards',
                  color: TermexColors.success,
                ),
              ),
            ),
            const SizedBox(width: TermexSpacing.sm),
          ],
          // Update available dot
          if (hasUpdate) ...[
            const Tooltip(
              message: '有新版本可用 · 点击设置检查更新',
              child: _StatusDot(color: TermexColors.primary),
            ),
            const SizedBox(width: TermexSpacing.sm),
          ],
          // Tmux indicator
          if (isTmuxAttached) ...[
            const Tooltip(
              message: '检测到 tmux 多路复用',
              child: _StatusChip(
                icon: Icons.dashboard_customize,
                label: 'tmux',
                color: TermexColors.primary,
              ),
            ),
            const SizedBox(width: TermexSpacing.sm),
          ],
          // Broadcast indicator
          if (broadcast.hasFanout) ...[
            Text(
              'Broadcast: ${broadcast.members.length}',
              style: TermexTypography.caption.copyWith(
                color: TermexColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: TermexSpacing.md),
          ],
          Text(
            'UTF-8',
            style: TermexTypography.caption.copyWith(
              color: TermexColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusFor(WidgetRef ref, String? tabId) {
    if (tabId == null) {
      return ('Ready', TermexColors.textMuted);
    }
    final c = ref.watch(connectionProvider(tabId));
    return switch (c.status) {
      ReconnectStatus.idle => ('Ready', TermexColors.textMuted),
      ReconnectStatus.connecting => ('Connecting…', TermexColors.warning),
      ReconnectStatus.reconnecting => (
          'Reconnecting (attempt ${c.reconnectAttempt})…',
          TermexColors.warning
        ),
      ReconnectStatus.connected => ('Connected', TermexColors.success),
      ReconnectStatus.failed => (
          'Failed: ${c.lastError ?? 'unknown'}',
          TermexColors.danger
        ),
      ReconnectStatus.closed => ('Disconnected', TermexColors.textMuted),
    };
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: TermexTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Team sync indicator widget was removed with the OSS PC build's drop of
// the team feature (Phase 4); it lives in the commercial UI shipped via
// `termex_shared_pro`.
