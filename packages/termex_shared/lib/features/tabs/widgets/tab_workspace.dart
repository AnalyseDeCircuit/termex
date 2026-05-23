/// Per-session workspace: SSH terminal + sub-tab bar (SSH/SFTP/传输/Monitor)
/// with optional split-panel layout. Mirrors Tauri's TabWorkspace.vue.
library;

import 'package:flutter/material.dart'
    show
        AlwaysStoppedAnimation,
        Colors,
        LinearProgressIndicator,
        Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/colors.dart';
// Monitor feature temporarily removed during the desktop/mobile package split
// (v0.69.0+).  The _SubTab.monitor case renders a placeholder until the
// monitor panel lands in its final location (termex_shared / termex-mobile).
// import '../../monitor/monitor_panel.dart';
import '../../sftp/sftp_panel.dart';
import '../../sftp/state/sftp_transfer_provider.dart'
    show sftpTransferProvider, TransferDirection, TransferItem;
import '../../../terminal/pane/terminal_pane.dart';
import '../state/tab_controller.dart' show pendingSftpTabProvider;

// ─── State ───────────────────────────────────────────────────────────────────

enum _SubTab { ssh, sftp, transfers, monitor }

enum _Layout { tabs, splitRight, splitBottom }

// ─── Widget ──────────────────────────────────────────────────────────────────

/// Workspace that wraps a live SSH terminal with the SSH/SFTP/传输/Monitor
/// sub-tab bar. Supports tabbed overlay mode and horizontal / vertical split.
class TabWorkspace extends ConsumerStatefulWidget {
  final String sessionId;

  /// True when this tab is a local PTY (not SSH). Local tabs disable the
  /// SFTP and Transfers sub-tabs because both require an SSH session.
  final bool isLocal;

  const TabWorkspace({
    super.key,
    required this.sessionId,
    this.isLocal = false,
  });

  @override
  ConsumerState<TabWorkspace> createState() => _TabWorkspaceState();
}

class _TabWorkspaceState extends ConsumerState<TabWorkspace> {
  _SubTab _subTab = _SubTab.ssh;
  _Layout _layout = _Layout.tabs;
  // Which group is in the split panel (when layout != tabs)
  _SubTab _splitGroup = _SubTab.sftp;
  double _splitRatio = 0.55; // terminal takes this fraction
  final bool _resizing = false;

  // Drag detection for panel tabs (SFTP / Monitor)
  Offset? _dragStart;

  static const double _minRatio = 0.25;
  static const double _maxRatio = 0.80;

  void _onPanelTabDragStart(Offset pos) {
    _dragStart = pos;
  }

  void _onPanelTabDragEnd(Offset pos, _SubTab group) {
    if (_dragStart == null) return;
    final delta = pos - _dragStart!;
    _dragStart = null;

    final absDx = delta.dx.abs();
    final absDy = delta.dy.abs();

    if (absDx < 20 && absDy < 20) {
      // Too small — treat as tap, switch sub-tab
      setState(() {
        _subTab = group;
        _layout = _Layout.tabs;
      });
      return;
    }

    if (absDx >= absDy) {
      // Horizontal drag → split right
      setState(() {
        _splitGroup = group;
        _subTab = group;
        _layout = _Layout.splitRight;
      });
    } else {
      // Vertical drag → split bottom
      setState(() {
        _splitGroup = group;
        _subTab = group;
        _layout = _Layout.splitBottom;
      });
    }
  }

  void _closeSplit() => setState(() {
        _layout = _Layout.tabs;
        _subTab = _SubTab.ssh;
      });

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingSftpTabProvider, (_, next) {
      if (next == widget.sessionId) {
        setState(() => _subTab = _SubTab.sftp);
        ref.read(pendingSftpTabProvider.notifier).state = null;
      }
    });

    final transferCount = ref.watch(
        sftpTransferProvider(widget.sessionId)
            .select((s) => s.active.length));

    switch (_layout) {
      case _Layout.tabs:
        return _buildTabsMode(transferCount);
      case _Layout.splitRight:
        return _buildSplitMode(Axis.horizontal, transferCount);
      case _Layout.splitBottom:
        return _buildSplitMode(Axis.vertical, transferCount);
    }
  }

  // ── Tabs mode ──────────────────────────────────────────────────────────────

  Widget _buildTabsMode(int transferCount) {
    return Stack(
      children: [
        // Terminal always rendered with 24px top space for the tab bar
        Positioned.fill(
          top: 24,
          child: TerminalPane(sessionId: widget.sessionId),
        ),
        // Overlay panel when non-SSH tab is active
        if (_subTab != _SubTab.ssh)
          Positioned.fill(
            top: 24,
            child: ColoredBox(
              color: TermexColors.backgroundSecondary,
              child: _panelContent(_subTab),
            ),
          ),
        // Floating tab bar at top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 24,
          child: _SubTabBar(
            sessionId: widget.sessionId,
            active: _subTab,
            layout: _layout,
            transferCount: transferCount,
            isLocal: widget.isLocal,
            onTap: (t) => setState(() => _subTab = t),
            onDragStart: _onPanelTabDragStart,
            onDragEnd: _onPanelTabDragEnd,
            onCloseSplit: null,
          ),
        ),
      ],
    );
  }

  // ── Split mode ─────────────────────────────────────────────────────────────

  Widget _buildSplitMode(Axis axis, int transferCount) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final total = axis == Axis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final mainSize = (total * _splitRatio).clamp(
            total * _minRatio, total * _maxRatio);
        final panelSize = total - mainSize - 4; // 4 = divider width

        Widget terminal = Stack(
          children: [
            Positioned.fill(
              top: 24,
              child: TerminalPane(sessionId: widget.sessionId),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 24,
              child: _SubTabBar(
                sessionId: widget.sessionId,
                active: _SubTab.ssh,
                layout: _layout,
                transferCount: transferCount,
                isLocal: widget.isLocal,
                onTap: (t) {
                  if (t == _SubTab.ssh) {
                    _closeSplit();
                  } else {
                    setState(() => _splitGroup = t);
                  }
                },
                onDragStart: _onPanelTabDragStart,
                onDragEnd: _onPanelTabDragEnd,
                onCloseSplit: null,
              ),
            ),
          ],
        );

        Widget panel = Column(
          children: [
            _PanelTabBar(
              group: _splitGroup,
              sessionId: widget.sessionId,
              transferCount: transferCount,
              onSwitch: (t) => setState(() => _splitGroup = t),
              onClose: _closeSplit,
            ),
            Expanded(child: _panelContent(_splitGroup)),
          ],
        );

        Widget resizeHandle = GestureDetector(
          onPanUpdate: (d) {
            if (!mounted) return;
            setState(() {
              if (axis == Axis.horizontal) {
                _splitRatio = (_splitRatio + d.delta.dx / total)
                    .clamp(_minRatio, _maxRatio);
              } else {
                _splitRatio = (_splitRatio + d.delta.dy / total)
                    .clamp(_minRatio, _maxRatio);
              }
            });
          },
          child: MouseRegion(
            cursor: axis == Axis.horizontal
                ? SystemMouseCursors.resizeColumn
                : SystemMouseCursors.resizeRow,
            child: Container(
              width: axis == Axis.horizontal ? 4 : double.infinity,
              height: axis == Axis.vertical ? 4 : double.infinity,
              color: TermexColors.border,
            ),
          ),
        );

        if (axis == Axis.horizontal) {
          return Row(
            children: [
              SizedBox(width: mainSize, child: terminal),
              resizeHandle,
              SizedBox(width: panelSize, child: panel),
            ],
          );
        } else {
          return Column(
            children: [
              SizedBox(height: mainSize, child: terminal),
              resizeHandle,
              SizedBox(height: panelSize, child: panel),
            ],
          );
        }
      },
    );
  }

  // ── Panel content ──────────────────────────────────────────────────────────

  Widget _panelContent(_SubTab tab) {
    switch (tab) {
      case _SubTab.ssh:
        return TerminalPane(sessionId: widget.sessionId);
      case _SubTab.sftp:
        return SftpPanel(sessionId: widget.sessionId);
      case _SubTab.monitor:
        // Placeholder during v0.69.0+ desktop/mobile package split; the
        // MonitorPanel will be re-introduced once its target package is
        // settled (see v0.69.0 stabilization doc §6).
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Monitor panel is being relocated; please retry after the '
              'restructure stabilizes.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      case _SubTab.transfers:
        return _TransfersPanel(sessionId: widget.sessionId);
    }
  }
}

// ─── Floating sub-tab bar (tabs mode, overlaid on terminal top) ───────────────

class _SubTabBar extends ConsumerWidget {
  final String sessionId;
  final _SubTab active;
  final _Layout layout;
  final int transferCount;
  final bool isLocal;
  final void Function(_SubTab) onTap;
  final void Function(Offset) onDragStart;
  final void Function(Offset, _SubTab) onDragEnd;
  final VoidCallback? onCloseSplit;

  const _SubTabBar({
    required this.sessionId,
    required this.active,
    required this.layout,
    required this.transferCount,
    required this.onTap,
    required this.onDragStart,
    required this.onDragEnd,
    this.isLocal = false,
    this.onCloseSplit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 24,
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          _WorkspaceTab(
            label: 'SSH',
            active: active == _SubTab.ssh,
            onTap: () => onTap(_SubTab.ssh),
          ),
          _DraggableWorkspaceTab(
            label: 'SFTP',
            active: active == _SubTab.sftp,
            disabled: isLocal,
            disabledTooltip: '本地终端不支持 SFTP',
            onTap: () => onTap(_SubTab.sftp),
            onDragStart: onDragStart,
            onDragEnd: (pos) => onDragEnd(pos, _SubTab.sftp),
          ),
          _DraggableWorkspaceTab(
            label: '传输',
            active: active == _SubTab.transfers,
            badge: transferCount,
            disabled: isLocal,
            disabledTooltip: '本地终端不支持文件传输',
            onTap: () => onTap(_SubTab.transfers),
            onDragStart: onDragStart,
            onDragEnd: (pos) => onDragEnd(pos, _SubTab.transfers),
          ),
          _DraggableWorkspaceTab(
            label: 'Monitor',
            active: active == _SubTab.monitor,
            onTap: () => onTap(_SubTab.monitor),
            onDragStart: onDragStart,
            onDragEnd: (pos) => onDragEnd(pos, _SubTab.monitor),
          ),
          const Spacer(),
          if (onCloseSplit != null)
            _CloseBtn(onTap: onCloseSplit!),
        ],
      ),
    );
  }
}

// ─── Panel tab bar (used inside split panel) ─────────────────────────────────

class _PanelTabBar extends StatelessWidget {
  final _SubTab group;
  final String sessionId;
  final int transferCount;
  final void Function(_SubTab) onSwitch;
  final VoidCallback onClose;

  const _PanelTabBar({
    required this.group,
    required this.sessionId,
    required this.transferCount,
    required this.onSwitch,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          if (group == _SubTab.sftp || group == _SubTab.transfers) ...[
            _WorkspaceTab(
              label: 'SFTP',
              active: group == _SubTab.sftp,
              onTap: () => onSwitch(_SubTab.sftp),
            ),
            _WorkspaceTab(
              label: '传输',
              active: group == _SubTab.transfers,
              badge: transferCount,
              onTap: () => onSwitch(_SubTab.transfers),
            ),
          ] else ...[
            _WorkspaceTab(
              label: 'Monitor',
              active: true,
              onTap: () {},
            ),
          ],
          const Spacer(),
          _CloseBtn(onTap: onClose),
        ],
      ),
    );
  }
}

// ─── Tab chip ─────────────────────────────────────────────────────────────────

class _WorkspaceTab extends StatefulWidget {
  final String label;
  final bool active;
  final int badge;
  final VoidCallback? onTap;

  const _WorkspaceTab({
    required this.label,
    required this.active,
    this.badge = 0,
    this.onTap,
  });

  @override
  State<_WorkspaceTab> createState() => _WorkspaceTabState();
}

class _WorkspaceTabState extends State<_WorkspaceTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.active
                    ? TermexColors.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  color: widget.active
                      ? TermexColors.textPrimary
                      : _hovered
                          ? TermexColors.textSecondary
                          : TermexColors.textMuted,
                ),
              ),
              if (widget.badge > 0) ...[
                const SizedBox(width: 3),
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.badge}',
                    style: const TextStyle(
                        fontSize: 8,
                        color: Color(0xFFFFFFFF),
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A workspace tab that also supports drag to enter split mode.
///
/// When [disabled] is true, the tab renders muted, does not respond to tap
/// or drag, shows a forbidden cursor, and surfaces [disabledTooltip] on hover.
class _DraggableWorkspaceTab extends StatefulWidget {
  final String label;
  final bool active;
  final int badge;
  final bool disabled;
  final String? disabledTooltip;
  final VoidCallback? onTap;
  final void Function(Offset) onDragStart;
  final void Function(Offset) onDragEnd;

  const _DraggableWorkspaceTab({
    required this.label,
    required this.active,
    this.badge = 0,
    this.disabled = false,
    this.disabledTooltip,
    this.onTap,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  State<_DraggableWorkspaceTab> createState() => _DraggableWorkspaceTabState();
}

class _DraggableWorkspaceTabState extends State<_DraggableWorkspaceTab> {
  bool _hovered = false;
  Offset? _panStart;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.disabled;
    Widget tab = MouseRegion(
      cursor: disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: disabled ? null : widget.onTap,
        behavior: HitTestBehavior.opaque,
        onPanStart: disabled
            ? null
            : (d) {
                _panStart = d.globalPosition;
                widget.onDragStart(d.globalPosition);
              },
        onPanEnd: disabled
            ? null
            : (d) {
                if (_panStart != null) {
                  widget.onDragEnd(
                      d.localPosition + (_panStart ?? Offset.zero));
                }
              },
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: widget.active && !disabled
                      ? TermexColors.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: disabled
                        ? TermexColors.textMuted
                        : widget.active
                            ? TermexColors.textPrimary
                            : _hovered
                                ? TermexColors.textSecondary
                                : TermexColors.textMuted,
                  ),
                ),
                if (widget.badge > 0) ...[
                  const SizedBox(width: 3),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.badge}',
                      style: const TextStyle(
                          fontSize: 8,
                          color: Color(0xFFFFFFFF),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (disabled && widget.disabledTooltip != null) {
      tab = Tooltip(message: widget.disabledTooltip!, child: tab);
    }
    return tab;
  }
}

class _CloseBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseBtn({required this.onTap});

  @override
  State<_CloseBtn> createState() => _CloseBtnState();
}

class _CloseBtnState extends State<_CloseBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 24,
          alignment: Alignment.center,
          child: Text(
            '✕',
            style: TextStyle(
              fontSize: 11,
              color: _hovered
                  ? const Color(0xFFF87171)
                  : TermexColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Inline transfers panel ───────────────────────────────────────────────────

class _TransfersPanel extends ConsumerWidget {
  final String sessionId;
  const _TransfersPanel({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(sftpTransferProvider(sessionId)).items;
    if (transfers.isEmpty) {
      return const Center(
        child: Text(
          '暂无传输任务',
          style: TextStyle(fontSize: 12, color: TermexColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: transfers.length,
      itemBuilder: (ctx, i) {
        final t = transfers[i];
        final pct = t.totalBytes > 0
            ? t.transferredBytes / t.totalBytes
            : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    t.direction == TransferDirection.upload ? '↑' : '↓',
                    style: TextStyle(
                      fontSize: 11,
                      color: t.direction == TransferDirection.upload
                          ? TermexColors.primary
                          : TermexColors.success,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      t.fileName,
                      style: const TextStyle(
                          fontSize: 11, color: TermexColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 10, color: TermexColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              LinearProgressIndicator(
                value: pct.toDouble(),
                backgroundColor: TermexColors.backgroundTertiary,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(TermexColors.primary),
                minHeight: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
