import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
import '../../../design/spacing.dart';
import '../../../design/typography.dart';
import '../../../icons/termex_icons.dart';
import '../../../widgets/button.dart';
import '../../server_list/state/connection_provider.dart';
import '../../server_list/state/session_provider.dart';
import '../state/tab_controller.dart';

/// Content area for a single tab.
///
/// Renders:
/// - A connecting/loading view while the SSH handshake is in progress.
/// - An error view with a Reconnect button when the connection has failed.
/// - A disconnected view with a Reconnect button when the tab is closed.
/// - The terminal widget (slot via [terminalBuilder]) when connected.
///
/// The actual [TerminalView] widget lives in v0.41 and is injected via
/// [terminalBuilder] to keep this widget free of a hard dependency on the
/// terminal package (which may not be available in tests).
class TabContent extends ConsumerWidget {
  /// The ID of the tab this widget represents.
  final String tabId;

  /// Builder called when the session is connected.
  ///
  /// [sessionId] is the active SSH session identifier.
  final Widget Function(BuildContext context, String sessionId)?
      terminalBuilder;

  const TabContent({
    super.key,
    required this.tabId,
    this.terminalBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref
        .watch(tabListProvider)
        .where((t) => t.id == tabId)
        .firstOrNull;

    if (tab == null) {
      return const _EmptyPane();
    }

    final connection = ref.watch(connectionProvider(tabId));
    final session = ref.watch(sessionProvider(tab.serverId));

    switch (connection.status) {
      case ReconnectStatus.connecting:
      case ReconnectStatus.reconnecting:
        return _ConnectingView(
          reconnectAttempt: connection.reconnectAttempt,
          isReconnecting: connection.status == ReconnectStatus.reconnecting,
        );

      case ReconnectStatus.connected:
        final sessionId = session.sessionId;
        if (sessionId != null && terminalBuilder != null) {
          return terminalBuilder!(context, sessionId);
        }
        // Fallback while terminal widget is wired up.
        return _PlaceholderTerminalView(sessionId: sessionId);

      case ReconnectStatus.failed:
        return _ErrorView(
          error: connection.lastError ?? 'Connection failed.',
          onReconnect: () => _reconnect(ref, tab.serverId),
        );

      case ReconnectStatus.closed:
        return _DisconnectedView(
          serverName: tab.title,
          onReconnect: () => _reconnect(ref, tab.serverId),
        );

      case ReconnectStatus.idle:
        return const _EmptyPane();
    }
  }

  void _reconnect(WidgetRef ref, String serverId) {
    ref.read(connectionProvider(tabId).notifier).connect(serverId);
  }
}

// ─── Private view widgets ────────────────────────────────────────────────────

class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: TermexColors.backgroundPrimary);
  }
}

class _ConnectingView extends StatelessWidget {
  final int reconnectAttempt;
  final bool isReconnecting;

  const _ConnectingView({
    required this.reconnectAttempt,
    required this.isReconnecting,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TermexColors.backgroundPrimary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Spinner(),
            const SizedBox(height: TermexSpacing.lg),
            Text(
              isReconnecting
                  ? 'Reconnecting… (attempt $reconnectAttempt)'
                  : 'Connecting…',
              style: TermexTypography.body.copyWith(
                color: TermexColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onReconnect;

  const _ErrorView({required this.error, required this.onReconnect});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TermexColors.backgroundPrimary,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(TermexSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TermexIconWidget(
                TermexIcons.warning,
                size: 32,
                color: TermexColors.danger,
              ),
              const SizedBox(height: TermexSpacing.md),
              Text(
                'Connection failed',
                style: TermexTypography.body.copyWith(
                  color: TermexColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: TermexSpacing.sm),
              Text(
                error,
                style: TermexTypography.bodySmall.copyWith(
                  color: TermexColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: TermexSpacing.xl),
              TermexButton(
                label: 'Reconnect',
                variant: ButtonVariant.primary,
                onPressed: onReconnect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisconnectedView extends StatelessWidget {
  final String serverName;
  final VoidCallback onReconnect;

  const _DisconnectedView({
    required this.serverName,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TermexColors.backgroundPrimary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TermexIconWidget(
              TermexIcons.server,
              size: 32,
              color: TermexColors.textMuted,
            ),
            const SizedBox(height: TermexSpacing.md),
            Text(
              'Disconnected from $serverName',
              style: TermexTypography.body.copyWith(
                color: TermexColors.textSecondary,
              ),
            ),
            const SizedBox(height: TermexSpacing.xl),
            TermexButton(
              label: 'Reconnect',
              variant: ButtonVariant.ghost,
              onPressed: onReconnect,
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder shown while the real TerminalView (v0.41) is not yet wired.
class _PlaceholderTerminalView extends StatelessWidget {
  final String? sessionId;
  const _PlaceholderTerminalView({this.sessionId});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1E1E2E),
      child: Center(
        child: Text(
          sessionId != null
              ? 'Terminal — session $sessionId'
              : 'Terminal (session pending)',
          style: TermexTypography.monospace.copyWith(
            color: const Color(0xFF89DCEB),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: const AlwaysStoppedAnimation<Color>(TermexColors.primary),
      ),
    );
  }
}
