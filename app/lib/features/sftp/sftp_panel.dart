/// SFTP dual-pane panel — top-level widget for the SFTP feature.
///
/// Composes the local pane, remote pane, transfer overlay, and handles
/// SFTP channel lifecycle (open on mount, close on dispose).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/colors.dart';
import 'state/sftp_pane_provider.dart';
import 'state/sftp_session_provider.dart';
import 'widgets/local_pane.dart';
import 'widgets/remote_pane.dart';
import 'widgets/transfer_progress_overlay.dart';

/// Full SFTP panel with dual-pane file browser and transfer progress.
///
/// [sessionId] must be the active SSH session ID. The widget opens the SFTP
/// channel automatically and closes it on dispose.
class SftpPanel extends ConsumerStatefulWidget {
  final String sessionId;

  const SftpPanel({super.key, required this.sessionId});

  @override
  ConsumerState<SftpPanel> createState() => _SftpPanelState();
}

class _SftpPanelState extends ConsumerState<SftpPanel> {
  @override
  void initState() {
    super.initState();
    // Open SFTP channel asynchronously after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sftpSessionProvider(widget.sessionId).notifier).open();
    });
  }

  @override
  void dispose() {
    ref.read(sftpSessionProvider(widget.sessionId).notifier).close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sftpState = ref.watch(sftpSessionProvider(widget.sessionId));

    if (sftpState.status == SftpChannelStatus.opening) {
      return const _LoadingView(message: '正在打开 SFTP 通道…');
    }
    if (sftpState.status == SftpChannelStatus.error) {
      return _ErrorView(message: sftpState.errorMessage ?? '未知错误');
    }

    return _PanelBody(sessionId: widget.sessionId);
  }
}

class _PanelBody extends ConsumerWidget {
  final String sessionId;

  const _PanelBody({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paneState = ref.watch(sftpPaneProvider(sessionId));

    return Stack(
      children: [
        Column(
          children: [
            // Toolbar
            _Toolbar(sessionId: sessionId),
            // Dual pane
            Expanded(
              child: _ResizableDualPane(
                ratio: paneState.splitRatio,
                onRatioChanged: (r) => ref
                    .read(sftpPaneProvider(sessionId).notifier)
                    .updateSplitRatio(r),
                left: LocalPane(
                  sessionId: sessionId,
                  remoteCurrentPath: paneState.remote.currentPath,
                ),
                right: RemotePane(
                  sessionId: sessionId,
                  localCurrentPath: paneState.local.currentPath,
                ),
              ),
            ),
          ],
        ),
        // Transfer overlay
        TransferProgressOverlay(sessionId: sessionId),
      ],
    );
  }
}

class _Toolbar extends ConsumerWidget {
  final String sessionId;

  const _Toolbar({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundTertiary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: const Row(
        children: [
          Icon(Icons.folder_copy_outlined,
              size: 16, color: TermexColors.textSecondary),
          SizedBox(width: 8),
          Text(
            'SFTP 文件传输',
            style: TextStyle(
              fontSize: 13,
              color: TermexColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResizableDualPane extends StatefulWidget {
  final double ratio;
  final ValueChanged<double> onRatioChanged;
  final Widget left;
  final Widget right;

  const _ResizableDualPane({
    required this.ratio,
    required this.onRatioChanged,
    required this.left,
    required this.right,
  });

  @override
  State<_ResizableDualPane> createState() => _ResizableDualPaneState();
}

class _ResizableDualPaneState extends State<_ResizableDualPane> {
  double? _dragRatio;

  @override
  Widget build(BuildContext context) {
    final ratio = _dragRatio ?? widget.ratio;

    return LayoutBuilder(builder: (context, constraints) {
      final total = constraints.maxWidth;
      final leftWidth = total * ratio;
      final rightWidth = total * (1 - ratio) - 5;

      return Row(
        children: [
          SizedBox(width: leftWidth, child: widget.left),
          // Divider / drag handle
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) {
                final newRatio =
                    ((ratio * total + (d.primaryDelta ?? 0)) / total)
                        .clamp(0.2, 0.8);
                setState(() => _dragRatio = newRatio);
              },
              onHorizontalDragEnd: (_) {
                if (_dragRatio != null) {
                  widget.onRatioChanged(_dragRatio!);
                  setState(() => _dragRatio = null);
                }
              },
              child: Container(
                width: 5,
                color: TermexColors.border,
              ),
            ),
          ),
          SizedBox(width: rightWidth, child: widget.right),
        ],
      );
    });
  }
}

class _LoadingView extends StatelessWidget {
  final String message;

  const _LoadingView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: TermexColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  color: TermexColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              color: TermexColors.danger, size: 36),
          const SizedBox(height: 8),
          Text(
            'SFTP 通道打开失败',
            style: const TextStyle(
                color: TermexColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(message,
              style: const TextStyle(
                  color: TermexColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
