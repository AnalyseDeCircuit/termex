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
import '../../../l10n/app_localizations.dart';
import '../../monitor/monitor_panel.dart';
import '../../sftp/sftp_panel.dart';
import '../../sftp/state/sftp_transfer_provider.dart'
    show sftpTransferProvider, TransferDirection, TransferItem;
import '../../../terminal/pane/terminal_pane.dart';
import '../../recording/widgets/recording_controls.dart';
import '../state/tab_controller.dart'
    show pendingSftpTabProvider, tabListProvider;

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
    // v0.77.0 parity: local PTY tabs don't need the SSH/SFTP/传输/Monitor
    // sub-tab bar — there's no remote host to SFTP into, no transfers,
    // and no metrics. Tauri/Vue baseline never showed it for local tabs,
    // and showing it with SFTP/传输 greyed-out felt cluttered. Hiding
    // the bar lets the terminal fill the full pane.
    final showSubTabs = !widget.isLocal;
    final topGap = showSubTabs ? 24.0 : 0.0;
    return Stack(
      children: [
        // Terminal fills below the sub-tab bar (or full pane for local).
        Positioned.fill(
          top: topGap,
          child: TerminalPane(sessionId: widget.sessionId),
        ),
        // Overlay panel when non-SSH tab is active.
        if (showSubTabs && _subTab != _SubTab.ssh)
          Positioned.fill(
            top: topGap,
            child: ColoredBox(
              color: context.colors.backgroundSecondary,
              child: _panelContent(_subTab),
            ),
          ),
        // Floating sub-tab bar at top — SSH tabs only.
        if (showSubTabs)
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
              color: context.colors.border,
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
        // v0.77.0 PC final parity: real MonitorPanel restored to OSS
        // termex_shared. Heavy remote stats collection still lives behind
        // the `private` Cargo feature — the panel surfaces a "stub data"
        // banner when bridge returns zeros, matching legacy Tauri OSS.
        return MonitorPanel(sessionId: widget.sessionId);
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
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: context.colors.border)),
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
            disabledTooltip: l10n.tabWorkspaceSftpLocalDisabled,
            onTap: () => onTap(_SubTab.sftp),
            onDragStart: onDragStart,
            onDragEnd: (pos) => onDragEnd(pos, _SubTab.sftp),
          ),
          _DraggableWorkspaceTab(
            label: l10n.sftpTransfers,
            active: active == _SubTab.transfers,
            badge: transferCount,
            disabled: isLocal,
            disabledTooltip: l10n.tabWorkspaceTransfersLocalDisabled,
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
          // Session recording. The Tauri build placed this control in the
          // terminal chrome (RecordingControls.vue in TabWorkspace.vue); the
          // Flutter port had no entry point for it at all. Local PTY tabs are
          // excluded — the recorder keys off an SSH session.
          if (!isLocal) _RecordingSlot(sessionId: sessionId),
          if (onCloseSplit != null)
            _CloseBtn(onTap: onCloseSplit!),
        ],
      ),
    );
  }
}

/// Resolves the tab's server identity, which the asciicast header needs, and
/// renders the control. Split out so _SubTabBar stays declarative.
class _RecordingSlot extends ConsumerWidget {
  final String sessionId;
  const _RecordingSlot({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref
        .watch(tabListProvider)
        .where((t) => t.id == sessionId)
        .firstOrNull;
    if (tab == null) return const SizedBox.shrink();
    return RecordingControls(
      sessionId: sessionId,
      serverId: tab.serverId,
      serverName: tab.title,
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
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: context.colors.border)),
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
              label: l10n.sftpTransfers,
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
                    ? context.colors.primary
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
                      ? context.colors.textPrimary
                      : _hovered
                          ? context.colors.textSecondary
                          : context.colors.textMuted,
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
                      ? context.colors.primary
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
                        ? context.colors.textMuted
                        : widget.active
                            ? context.colors.textPrimary
                            : _hovered
                                ? context.colors.textSecondary
                                : context.colors.textMuted,
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
                  : context.colors.textSecondary,
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
      return Center(
        child: Text(
          AppLocalizations.of(context).tabWorkspaceNoTransfers,
          style: TextStyle(fontSize: 12, color: context.colors.textMuted),
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
                          ? context.colors.primary
                          : context.colors.success,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      t.fileName,
                      style: TextStyle(
                          fontSize: 11, color: context.colors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 10, color: context.colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              LinearProgressIndicator(
                value: pct.toDouble(),
                backgroundColor: context.colors.backgroundTertiary,
                valueColor:
                    AlwaysStoppedAnimation<Color>(context.colors.primary),
                minHeight: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
