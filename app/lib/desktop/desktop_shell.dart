import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/design/spacing.dart';
import 'package:termex_shared/design/typography.dart';
import 'package:termex_shared/features/ai/panel/ai_panel.dart';
import 'package:termex_shared/features/command_palette/command_palette.dart';
import 'package:termex_shared/features/server_list/models/server_dto.dart';
import 'package:termex_shared/features/server_list/state/connection_provider.dart';
import 'package:termex_shared/features/server_list/state/server_provider.dart';
import '../cross_tab/cross_tab_search_dialog.dart';
import 'package:termex_shared/features/server_list/widgets/passphrase_dialog.dart';
import 'package:termex_shared/features/server_list/widgets/quick_connect_dialog.dart';
import 'package:termex_shared/features/server_list/widgets/server_form_dialog.dart';
import 'package:termex_shared/features/settings/settings_page.dart';
import 'package:termex_shared/features/snippet/snippet_palette.dart';
import 'package:termex_shared/features/port_forward/port_forward_panel.dart';
import 'package:termex_shared/features/sftp/sftp_panel.dart';
import 'package:termex_shared/terminal/state/terminal_action_provider.dart';
import 'package:termex_shared/widgets/dialog.dart';
import 'package:termex_shared/features/tabs/state/tab_controller.dart';
import 'package:termex_shared/features/tabs/widgets/tab_bar.dart';
import 'package:termex_shared/features/tabs/widgets/tab_content.dart';
import 'package:termex_shared/icons/termex_icons.dart';
import 'package:termex_shared/terminal/broadcast_registry.dart';
import 'package:termex_shared/features/tabs/widgets/tab_workspace.dart';
import 'desktop_sidebar.dart';
import 'desktop_status_bar.dart';
import 'state/desktop_shell_state.dart';

/// Top-level desktop shell for macOS / Windows / Linux.
///
/// Mirrors the production Tauri/Vue layout:
///
///   ┌────────────────────────────────────────────────────────────┐
///   │  (traffic lights · 80px) [tab bar]      [✨][⚙]           │ 36 top bar
///   ├────────────┬───────────────────────────────────────────────┤
///   │ Termex ▾   │   Tab content                                  │
///   │ ▤ ⊕ ⟨⟩ ⏺ ☁ │   (or branded splash when no tabs are open)    │
///   │ 🔍 Search… │                                                │
///   │ ▾ Group    │                              [side panel]      │
///   │   server   │                                                │
///   ├────────────┴───────────────────────────────────────────────┤
///   │ Ready                                                UTF-8  │ 22 status bar
///   └────────────────────────────────────────────────────────────┘
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  // ── Tab → server connect ──────────────────────────────────────────────────

  void _connectServerById(String serverId) {
    final server = ref.read(serverByIdProvider(serverId));
    if (server == null) return;
    _connectServer(server);
  }

  void _connectServer(ServerDto server) {
    final tabId = ref.read(tabListProvider.notifier).openTab(
          server.id,
          server.name,
        );
    ref.read(connectionProvider(tabId).notifier).connect(
          server.id,
          onPassphraseNeeded: () => _promptPassphrase(server),
        );
    ref.read(serverListProvider.notifier).updateLastConnected(server.id);
  }

  void _openLocalTerminal() {
    final tabId = ref.read(tabListProvider.notifier).openLocalTab();
    ref.read(connectionProvider(tabId).notifier).connectLocal();
  }

  void _connectServerByIdWithSftp(String serverId) {
    final server = ref.read(serverByIdProvider(serverId));
    if (server == null) return;
    final tabId = ref.read(tabListProvider.notifier).openTab(
          server.id,
          server.name,
        );
    ref.read(pendingSftpTabProvider.notifier).state = tabId;
    ref.read(connectionProvider(tabId).notifier).connect(
          server.id,
          onPassphraseNeeded: () => _promptPassphrase(server),
        );
    ref.read(serverListProvider.notifier).updateLastConnected(server.id);
  }

  // ── Keyboard shortcuts ────────────────────────────────────────────────────

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final mod = meta || ctrl;

    if (mod && event.logicalKey == LogicalKeyboardKey.keyT) {
      ref.read(newTabMenuTriggerProvider.notifier).update((n) => n + 1);
      return KeyEventResult.handled;
    }
    if (mod && event.logicalKey == LogicalKeyboardKey.keyW) {
      final activeId = ref.read(activeTabIdProvider);
      if (activeId != null) {
        ref.read(tabListProvider.notifier).closeTab(activeId);
      }
      return KeyEventResult.handled;
    }
    if (mod && !shift && event.logicalKey == LogicalKeyboardKey.keyN) {
      ServerFormDialog.show(context);
      return KeyEventResult.handled;
    }
    if (mod && event.logicalKey == LogicalKeyboardKey.comma) {
      _openSettingsDialog();
      return KeyEventResult.handled;
    }
    if (mod && event.logicalKey == LogicalKeyboardKey.backslash) {
      ref.read(sidebarVisibleProvider.notifier).update((v) => !v);
      return KeyEventResult.handled;
    }
    if (mod && shift && event.logicalKey == LogicalKeyboardKey.keyI) {
      toggleDesktopSidePanel(ref, DesktopSidePanel.ai);
      return KeyEventResult.handled;
    }
    if (mod && shift && event.logicalKey == LogicalKeyboardKey.keyB) {
      final activeId = ref.read(activeTabIdProvider);
      final sid = activeId == null ? null : _sessionIdFor(activeId);
      if (sid != null) ref.read(broadcastRegistryProvider).toggle(sid);
      return KeyEventResult.handled;
    }
    if (mod && shift && event.logicalKey == LogicalKeyboardKey.keyK) {
      QuickConnectDialog.show(context, onConnect: _connectServer);
      return KeyEventResult.handled;
    }
    if (mod && shift && event.logicalKey == LogicalKeyboardKey.keyF) {
      CrossTabSearchDialog.show(context);
      return KeyEventResult.handled;
    }
    if (mod && shift && event.logicalKey == LogicalKeyboardKey.keyS) {
      SnippetPalette.show(context);
      return KeyEventResult.handled;
    }
    // Cmd+Shift+P → Command Palette
    if (mod && shift && event.logicalKey == LogicalKeyboardKey.keyP) {
      ref.read(commandPaletteOpenProvider.notifier).state = true;
      return KeyEventResult.handled;
    }

    // Cmd+[ → previous tab
    if (mod && !shift && event.logicalKey == LogicalKeyboardKey.bracketLeft) {
      _cycleTabs(-1);
      return KeyEventResult.handled;
    }
    // Cmd+] → next tab
    if (mod && !shift && event.logicalKey == LogicalKeyboardKey.bracketRight) {
      _cycleTabs(1);
      return KeyEventResult.handled;
    }
    // Cmd+Alt+← → move active tab left
    if (mod && HardwareKeyboard.instance.isAltPressed &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveActiveTab(-1);
      return KeyEventResult.handled;
    }
    // Cmd+Alt+→ → move active tab right
    if (mod && HardwareKeyboard.instance.isAltPressed &&
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveActiveTab(1);
      return KeyEventResult.handled;
    }
    // Escape → close active side panel
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      final sidePanel = ref.read(desktopSidePanelProvider);
      if (sidePanel != DesktopSidePanel.none) {
        ref.read(desktopSidePanelProvider.notifier).state =
            DesktopSidePanel.none;
        return KeyEventResult.handled;
      }
    }

    // Terminal action shortcuts — dispatched via activeTerminalActionProvider
    void dispatchTerminalAction(TerminalAction action) {
      ref.read(activeTerminalActionProvider.notifier).state = action;
    }

    if (mod && !shift && event.logicalKey == LogicalKeyboardKey.keyK) {
      dispatchTerminalAction(TerminalAction.clearScrollback);
      return KeyEventResult.handled;
    }
    if (mod && !shift && event.logicalKey == LogicalKeyboardKey.keyF) {
      dispatchTerminalAction(TerminalAction.search);
      return KeyEventResult.handled;
    }
    if (mod && shift && event.logicalKey == LogicalKeyboardKey.keyC) {
      dispatchTerminalAction(TerminalAction.copySelection);
      return KeyEventResult.handled;
    }
    if (mod && shift && event.logicalKey == LogicalKeyboardKey.keyV) {
      dispatchTerminalAction(TerminalAction.paste);
      return KeyEventResult.handled;
    }

    final digits = {
      LogicalKeyboardKey.digit1: 0,
      LogicalKeyboardKey.digit2: 1,
      LogicalKeyboardKey.digit3: 2,
      LogicalKeyboardKey.digit4: 3,
      LogicalKeyboardKey.digit5: 4,
      LogicalKeyboardKey.digit6: 5,
      LogicalKeyboardKey.digit7: 6,
      LogicalKeyboardKey.digit8: 7,
      LogicalKeyboardKey.digit9: 8,
    };
    if (mod && digits.containsKey(event.logicalKey)) {
      final tabs = ref.read(tabListProvider);
      final idx = digits[event.logicalKey]!;
      if (idx < tabs.length) {
        ref.read(activeTabIdProvider.notifier).state = tabs[idx].id;
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _cycleTabs(int direction) {
    final tabs = ref.read(tabListProvider);
    if (tabs.isEmpty) return;
    final activeId = ref.read(activeTabIdProvider);
    final current = tabs.indexWhere((t) => t.id == activeId);
    final next = (current + direction).clamp(0, tabs.length - 1);
    ref.read(activeTabIdProvider.notifier).state = tabs[next].id;
  }

  void _moveActiveTab(int direction) {
    final tabs = ref.read(tabListProvider);
    if (tabs.isEmpty) return;
    final activeId = ref.read(activeTabIdProvider);
    final current = tabs.indexWhere((t) => t.id == activeId);
    if (current == -1) return;
    final next = (current + direction).clamp(0, tabs.length - 1);
    if (next != current) {
      ref.read(tabListProvider.notifier).reorderTab(current, next);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(tabListProvider);
    final activeId = ref.watch(activeTabIdProvider);
    final sidePanel = ref.watch(desktopSidePanelProvider);
    final sidebarVisible = ref.watch(sidebarVisibleProvider);

    final paletteOpen = ref.watch(commandPaletteOpenProvider);

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Stack(
        children: [
          ColoredBox(
            color: TermexColors.backgroundPrimary,
            child: Column(
              children: [
                _DesktopTopBar(
                  activePanel: sidePanel,
                  onPanelToggle: (p) => toggleDesktopSidePanel(ref, p),
                  onNewTab: _connectServer,
                  onLocalTerminal: _openLocalTerminal,
                ),
                Expanded(
                  child: Row(
                    children: [
                      if (sidebarVisible)
                        DesktopSidebar(
                          onConnectServer: _connectServerById,
                          onConnectServerWithSftp: _connectServerByIdWithSftp,
                        ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: tabs.isEmpty
                                  ? const DesktopWelcomePane()
                                  : IndexedStack(
                                      index: tabs.indexWhere(
                                          (t) => t.id == activeId),
                                      children: tabs
                                          .map((tab) => TabContent(
                                                key: ValueKey(tab.id),
                                                tabId: tab.id,
                                                terminalBuilder:
                                                    (ctx, sessionId) =>
                                                        TabWorkspace(
                                                          sessionId: sessionId,
                                                          isLocal: tab.isLocal,
                                                        ),
                                              ))
                                          .toList(),
                                    ),
                            ),
                            if (sidePanel != DesktopSidePanel.none)
                              _SidePanelContainer(
                                panel: sidePanel,
                                sessionId: activeId == null
                                    ? null
                                    : _sessionIdFor(activeId),
                                onClose: () => ref
                                    .read(desktopSidePanelProvider.notifier)
                                    .state = DesktopSidePanel.none,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const DesktopStatusBar(),
              ],
            ),
          ),
          if (paletteOpen) const CommandPalette(),
        ],
      ),
    );
  }

  String? _sessionIdFor(String tabId) =>
      ref.read(connectionProvider(tabId)).sessionId;

  Future<String?> _promptPassphrase(ServerDto server) async {
    if (!mounted) return null;
    final result = await showPassphraseDialog(
      context,
      serverName: server.name,
      keyPath: server.keyPath,
    );
    return result?.passphrase;
  }

  void _openSettingsDialog() {
    showTermexDialog<void>(
      context: context,
      title: '设置',
      size: DialogSize.large,
      body: const SizedBox(
        width: 680,
        height: 500,
        child: SettingsPage(embedded: true),
      ),
    );
  }
}

// ─── Top bar ────────────────────────────────────────────────────────────────

class _DesktopTopBar extends ConsumerWidget {
  final DesktopSidePanel activePanel;
  final void Function(DesktopSidePanel) onPanelToggle;
  final void Function(ServerDto) onNewTab;
  final VoidCallback onLocalTerminal;

  const _DesktopTopBar({
    required this.activePanel,
    required this.onPanelToggle,
    required this.onNewTab,
    required this.onLocalTerminal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidebarVisible = ref.watch(sidebarVisibleProvider);
    // When the sidebar is visible (240px wide), the tab bar should start at
    // the sidebar's right edge so it visually aligns with the content area.
    // When hidden, reserve only the 78px traffic-light area.
    final leftInset = sidebarVisible ? 240.0 : 78.0;
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: TermexColors.backgroundPrimary,
        border: Border(
          bottom: BorderSide(color: TermexColors.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: leftInset,
          ),
          Expanded(
            child: TermexTabBar(
              onNewTab: onNewTab,
              onLocalTerminal: onLocalTerminal,
            ),
          ),
          // Right-side icon cluster — only sparkle (AI) + cog (Settings),
          // matching `TerminalTabs.vue` in the Tauri build. SFTP is reached
          // per-tab from the terminal pane, not from the global top bar.
          _TopBarIconButton(
            icon: TermexIcons.ai,
            tooltip: 'AI Assistant',
            active: activePanel == DesktopSidePanel.ai,
            highlightWhenActive: TermexColors.primary,
            onTap: () => onPanelToggle(DesktopSidePanel.ai),
          ),
          _TopBarIconButton(
            icon: TermexIcons.settings,
            tooltip: 'Settings',
            active: false,
            onTap: () {
              final state = context
                  .findAncestorStateOfType<_DesktopShellState>();
              state?._openSettingsDialog();
            },
          ),
          const SizedBox(width: TermexSpacing.sm),
        ],
      ),
    );
  }
}

class _TopBarIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final Color? highlightWhenActive;
  final VoidCallback onTap;

  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    this.highlightWhenActive,
    required this.onTap,
  });

  @override
  State<_TopBarIconButton> createState() => _TopBarIconButtonState();
}

class _TopBarIconButtonState extends State<_TopBarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        widget.highlightWhenActive ?? TermexColors.primary;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 28,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.active
                  ? activeColor.withOpacity(0.12)
                  : (_hovered
                      ? TermexColors.backgroundTertiary
                      : null),
              borderRadius: BorderRadius.circular(6),
            ),
            child: TermexIconWidget(
              widget.icon,
              size: 16,
              color: widget.active
                  ? activeColor
                  : TermexColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Side panel container ───────────────────────────────────────────────────

class _SidePanelContainer extends StatelessWidget {
  final DesktopSidePanel panel;
  final String? sessionId;
  final VoidCallback onClose;

  const _SidePanelContainer({
    required this.panel,
    required this.sessionId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(left: BorderSide(color: TermexColors.border)),
      ),
      child: switch (panel) {
        DesktopSidePanel.sftp => sessionId != null
            ? SftpPanel(sessionId: sessionId!)
            : const _NoSessionPane(),
        DesktopSidePanel.ai => const AiPanel(),
        DesktopSidePanel.settings => const SettingsPage(),
        DesktopSidePanel.portForward => sessionId != null
            ? PortForwardPanel(sessionId: sessionId!)
            : const _NoSessionPane(),
        DesktopSidePanel.none => const SizedBox.shrink(),
      },
    );
  }
}

// ─── Welcome pane (no open tabs) — branded ─────────────────────────────────

class DesktopWelcomePane extends StatelessWidget {
  const DesktopWelcomePane({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TermexColors.backgroundPrimary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Termex',
              style: TermexTypography.heading1.copyWith(
                color: TermexColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 44,
              ),
            ),
            const SizedBox(height: TermexSpacing.sm),
            Text(
              '一款开源 AI 驱动的本地 SSH 客户端',
              style: TermexTypography.body.copyWith(
                color: TermexColors.textSecondary,
              ),
            ),
            const SizedBox(height: TermexSpacing.xxl),
            Text(
              '⌘T new tab · ⌘W close · ⌘1–9 switch · ⌘⇧K Quick Connect',
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '⌘⇧F Find across tabs · ⌘⇧S Snippets · ⌘⇧I AI · ⌘⇧B Broadcast · ⌘, Settings',
              style: TermexTypography.caption.copyWith(
                color: TermexColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSessionPane extends StatelessWidget {
  const _NoSessionPane();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TermexColors.backgroundSecondary,
      child: Center(
        child: Text(
          'Connect to a server first',
          style: TermexTypography.body.copyWith(color: TermexColors.textMuted),
        ),
      ),
    );
  }
}
