/// SFTP file browser for mobile (single remote pane).
///
/// Opens an SSH session and an SFTP channel against [server], then surfaces
/// the existing `RemotePane` widget from the shared package. v0.78.0 ships
/// just the read path (ls + cd + view); upload/download/edit/chmod are
/// inherited from the shared widget but the desktop's drag-and-drop is
/// disabled on iOS (no file drag affordance).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_bridge/api.dart' as bridge;
import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/design/mobile_tokens.dart';
import 'package:termex_shared/design/typography.dart';
import 'package:termex_shared/features/server_list/models/server_dto.dart';
import 'package:termex_shared/features/sftp/state/sftp_session_provider.dart';
import 'package:termex_shared/features/sftp/widgets/remote_pane.dart';
import 'package:termex_shared/icons/termex_icons.dart';
import 'package:termex_shared/widgets/clickable.dart';

import 'background_service.dart';
import 'battery_nag.dart';

enum _SftpStatus { connecting, ready, failed }

class MobileSftpPage extends ConsumerStatefulWidget {
  final ServerDto server;
  const MobileSftpPage({super.key, required this.server});

  @override
  ConsumerState<MobileSftpPage> createState() => _MobileSftpPageState();
}

class _MobileSftpPageState extends ConsumerState<MobileSftpPage> {
  String? _sessionId;
  _SftpStatus _status = _SftpStatus.connecting;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_openSession());
  }

  Future<void> _openSession() async {
    try {
      final sid = await bridge.openSshSession(
        serverId: widget.server.id,
        cols: 80,
        rows: 24,
      );
      if (!mounted) return;
      // Open the SFTP channel after the SSH session is ready.
      ref.read(sftpSessionProvider(sid).notifier).open();
      setState(() {
        _sessionId = sid;
        _status = _SftpStatus.ready;
      });
      // Keep the process alive while the user has an SFTP session open;
      // released in dispose(). No-op on iOS.
      unawaited(MobileBackgroundService.acquire());
      // First-connect battery-optimisation prompt (Android only).
      unawaited(MobileBatteryNag.maybeShow(context));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _SftpStatus.failed;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    final sid = _sessionId;
    if (sid != null) {
      ref.read(sftpSessionProvider(sid).notifier).close();
      unawaited(bridge.closeSshSession(sessionId: sid));
      unawaited(MobileBackgroundService.release());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // v0.79.61: dropped `SizedBox(height: safe.top/bottom)`. Same fix
    // as MobileTerminalPage — MobileShell consumes safe-area insets
    // once at the shell level, so doubling here just paints dead bands.
    return Container(
      color: context.colors.backgroundPrimary,
      child: Column(
        children: [
          _HeaderBar(
            title: widget.server.name,
            subtitle: _statusText,
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_status) {
      case _SftpStatus.connecting:
        return Center(
          child: Text(
            'Opening SFTP channel…',
            style: TextStyle(
              color: context.colors.textSecondary,
              decoration: TextDecoration.none,
              fontSize: 15,
            ),
          ),
        );
      case _SftpStatus.failed:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              _errorMessage ?? 'Connection failed',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF38BA8),
                decoration: TextDecoration.none,
                fontSize: 14,
              ),
            ),
          ),
        );
      case _SftpStatus.ready:
        return RemotePane(sessionId: _sessionId!);
    }
  }

  String get _statusText {
    switch (_status) {
      case _SftpStatus.connecting:
        return 'Connecting to ${widget.server.host}…';
      case _SftpStatus.ready:
        return '${widget.server.username}@${widget.server.host}';
      case _SftpStatus.failed:
        return 'Connection failed';
    }
  }
}

class _HeaderBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  const _HeaderBar({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MobileTokens.navBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          Clickable(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Container(
              width: MobileTokens.minTouchTarget,
              height: MobileTokens.minTouchTarget,
              alignment: Alignment.center,
              child: Icon(
                TermexIcons.close,
                size: 22,
                color: context.colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TermexTypography.body.copyWith(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TermexTypography.caption.copyWith(
                    color: context.colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: MobileTokens.minTouchTarget),
        ],
      ),
    );
  }
}
