import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termex_shared/design/colors.dart';
import 'package:termex_shared/design/mobile_tokens.dart';
import 'package:termex_shared/design/typography.dart';
import 'package:termex_shared/icons/termex_icons.dart';
import 'package:termex_shared/features/ai/panel/ai_panel.dart';
import 'package:termex_shared/features/settings/settings_page.dart';
import 'package:termex_shared/features/proxy/proxy_panel.dart';
import 'package:termex_shared/l10n/app_localizations.dart';
import 'package:termex_shared/features/server_list/models/server_dto.dart';
import 'package:termex_shared/features/server_list/server_list_page.dart';
import 'package:termex_shared/features/server_list/widgets/server_form_dialog.dart';
import 'package:termex_shared/features/snippet/snippet_library.dart';
import 'package:termex_shared/widgets/bottom_bar.dart';

import 'mobile_settings_page.dart';
import 'mobile_sftp_page.dart';
import 'mobile_terminal_page.dart';
import 'task_history_page.dart';

/// Root UI for iOS / Android. On desktop the app routes to `DesktopShell`.
///
/// v0.77.1 scope: BottomBar four tabs; Terminal tab is a Navigator that
/// shows the server list as its root and pushes the terminal page when
/// a server is tapped.
class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({super.key});

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell> {
  int _index = 0;

  /// v0.79.56: deep-link target for the Settings tab. v0.79.62: stays
  /// non-null across rebuilds — consumption is signalled by bumping
  /// [_settingsInstanceCounter] which changes the [MobileSettingsPage]
  /// key and triggers a fresh build with the new initialTab.
  SettingsTab? _pendingSettingsTab;

  /// v0.79.62: incremented every time the AI onboarding CTA targets a
  /// new Settings sub-tab. Drives the `ValueKey` on the IndexedStack's
  /// MobileSettingsPage so deep-link navigation re-instantiates the
  /// page; routine tab switches keep the same key and preserve the
  /// user's sub-tab state.
  int _settingsInstanceCounter = 0;

  // Per-tab navigator keys so each tab maintains its own back stack.
  final _terminalNav = GlobalKey<NavigatorState>();
  final _filesNav = GlobalKey<NavigatorState>();
  final _aiNav = GlobalKey<NavigatorState>();

  /// v0.79.56: AI onboarding CTA callback. Switches to Settings tab and
  /// stamps a one-shot deep-link target so the SettingsPage opens
  /// directly on `SettingsTab.ai`. v0.79.62: bumps the settings counter
  /// so the IndexedStack-hosted MobileSettingsPage rebuilds with the
  /// new initialTab even though it has been kept alive.
  void _openSettingsAi() {
    setState(() {
      _pendingSettingsTab = SettingsTab.ai;
      _settingsInstanceCounter++;
      _index = 3;
    });
  }

  /// v0.79.62: each tab's widget is built once on first render and
  /// stays alive forever — hosted in an [IndexedStack] so the active
  /// tab is the only one shown. This preserves:
  ///   - The pushed `MobileTerminalPage` (Rust SSH session + xterm
  ///     buffer) when the user dips into Files / AI / Settings and
  ///     comes back. Pre-v0.79.62 the SSH was killed on every tab
  ///     switch.
  ///   - The per-tab Navigator GlobalKeys. Before v0.79.62 each
  ///     `setState(() => _index = i)` returned a different widget tree,
  ///     Flutter disposed the previous tab's `_xNav` GlobalKey holder,
  ///     and the framework eventually fired `_elements.contains(element)`
  ///     when a key collided mid-rebuild — leaving the entire shell in
  ///     a corrupted state where no panel would open until app restart.
  ///
  /// The trade-off: all four tabs are instantiated on first paint
  /// instead of lazily. For Termex this is fine — the heavy tabs
  /// (Terminal, Files) only build their server-list shells initially;
  /// real terminal sessions only spin up after the user taps a server.
  Widget _tabBody() {
    return IndexedStack(
      index: _index,
      sizing: StackFit.expand,
      children: [
        _TerminalTab(navKey: _terminalNav),
        _FilesTab(navKey: _filesNav),
        _AiTab(navKey: _aiNav, onConfigureAi: _openSettingsAi),
        MobileSettingsPage(
          // Key bumps only when a deep-link forces a fresh
          // `initialTab`; otherwise the page is reused so the user's
          // sub-tab navigation survives tab switches.
          key: ValueKey('settings-$_settingsInstanceCounter'),
          initialTab: _pendingSettingsTab,
        ),
      ],
    );
  }

  static const List<({IconData icon, String label})> _tabs = [
    (icon: TermexIcons.terminal, label: 'Terminal'),
    (icon: TermexIcons.folder, label: 'Files'),
    (icon: TermexIcons.ai, label: 'AI'),
    (icon: TermexIcons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safePadding = mediaQuery.padding;
    // Tablet layout kicks in at the same 900px breakpoint shared with the
    // adaptive layout module — large iPads, Android tablets, and macOS
    // windows that happen to host MobileShell (rare in production but
    // useful for testing) all get the side rail.
    final useSideRail = mediaQuery.size.width >= 900;

    return Container(
      color: TermexColors.backgroundPrimary,
      child: useSideRail
          ? _buildSideRailLayout(safePadding)
          : _buildBottomBarLayout(safePadding),
    );
  }

  /// iPhone / narrow Android: classic bottom-tab layout.
  Widget _buildBottomBarLayout(EdgeInsets safePadding) {
    return Column(
      children: [
        SizedBox(height: safePadding.top),
        Expanded(child: _tabBody()),
        TermexBottomBar(
          selectedIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: [
            for (final t in _tabs)
              BottomBarItem(
                icon: Icon(t.icon, size: 22),
                activeIcon: Icon(t.icon, size: 22),
                label: t.label,
              ),
          ],
        ),
        SizedBox(height: safePadding.bottom),
      ],
    );
  }

  /// iPad / desktop-wide: vertical NavRail on the left, tab body on the
  /// right. Keeps the same `_index` state and `_tabBody()` builder; only
  /// the chrome around it changes.
  Widget _buildSideRailLayout(EdgeInsets safePadding) {
    return Padding(
      padding: EdgeInsets.only(
        top: safePadding.top,
        bottom: safePadding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NavRail(
            selectedIndex: _index,
            tabs: _tabs,
            onTap: (i) => setState(() => _index = i),
          ),
          Container(
            width: 1,
            color: TermexColors.border,
          ),
          Expanded(child: _tabBody()),
        ],
      ),
    );
  }
}
/// Vertical rail used on tablets / wide windows. Mirrors `TermexBottomBar`
/// but rotated to the side so the detail pane fills the rest of the screen.
class _NavRail extends StatelessWidget {
  final int selectedIndex;
  final List<({IconData icon, String label})> tabs;
  final ValueChanged<int> onTap;

  const _NavRail({
    required this.selectedIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: ColoredBox(
        color: TermexColors.backgroundSecondary,
        child: Column(
          children: [
            const SizedBox(height: 16),
            for (int i = 0; i < tabs.length; i++)
              _NavRailItem(
                icon: tabs[i].icon,
                label: tabs[i].label,
                selected: selectedIndex == i,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavRailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavRailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? TermexColors.primary : TermexColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TermexTypography.caption.copyWith(
                  color: color,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Terminal tab content. On phone: single column with Navigator push
/// for the terminal page. On tablet (≥ 900px width): three-pane layout
/// where the NavRail (parent) + server list (here, fixed 280px) +
/// terminal detail (expanded) all stay visible at once.
class _TerminalTab extends ConsumerStatefulWidget {
  final GlobalKey<NavigatorState> navKey;
  const _TerminalTab({required this.navKey});

  @override
  ConsumerState<_TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends ConsumerState<_TerminalTab> {
  ServerDto? _selectedServer;

  /// v0.79.64: mirror the iPhone `_ServerListScreen` sub-tab state on
  /// iPad too. Pre-v0.79.64 the iPad tablet split was hard-wired to the
  /// server list — 代理 and 命令片段 panels were inaccessible. Now the
  /// 280pt left pane renders the same servers / proxies / snippets
  /// switcher as the iPhone bottom-bar terminal tab.
  _MobileSidebarCategory _category = _MobileSidebarCategory.servers;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 900;
    if (isTablet) {
      return _buildTabletLayout(context);
    }
    return Navigator(
      key: widget.navKey,
      onGenerateRoute: (settings) {
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (_, __, ___) => const _ServerListScreen(),
        );
      },
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Title + nav-bar "+" follow the active sub-tab — same dispatch
    // table as `_ServerListScreen` on iPhone (v0.79.59). Snippet's
    // startNew requires a WidgetRef; we have one because _TerminalTab
    // is now ConsumerStatefulWidget.
    final title = switch (_category) {
      _MobileSidebarCategory.servers => l10n.sidebarServers,
      _MobileSidebarCategory.proxies => l10n.sidebarProxies,
      _MobileSidebarCategory.snippets => l10n.sidebarSnippets,
    };
    final onAdd = switch (_category) {
      _MobileSidebarCategory.servers => () => ServerFormDialog.show(context),
      _MobileSidebarCategory.proxies => () => AddProxyDialog.show(context),
      _MobileSidebarCategory.snippets => () => SnippetLibrary.startNew(ref),
    };

    final leftPaneBody = switch (_category) {
      _MobileSidebarCategory.servers => ServerListPage(
          onServerTap: (s) => setState(() => _selectedServer = s),
        ),
      _MobileSidebarCategory.proxies => const ProxyPanel(),
      _MobileSidebarCategory.snippets => const SnippetLibrary(),
    };

    return _TabletSplitTab(
      leftPane: Column(
        children: [
          _TerminalTabHeader(title: title, onAddServer: onAdd),
          _MobileSidebarTabs(
            active: _category,
            onSelect: (c) => setState(() => _category = c),
          ),
          Expanded(child: leftPaneBody),
        ],
      ),
      rightPane: _category == _MobileSidebarCategory.servers &&
              _selectedServer != null
          ? MobileTerminalPage(
              key: ValueKey(_selectedServer!.id),
              server: _selectedServer!,
            )
          : _EmptyDetailPane(
              message: _category == _MobileSidebarCategory.servers
                  ? 'Select a server to open a terminal.'
                  : 'Switch back to Servers and pick one to open a terminal.',
            ),
    );
  }
}

/// Files tab content: same dual-mode pattern as the Terminal tab, but
/// taps open the SFTP browser instead of the terminal.
class _FilesTab extends StatefulWidget {
  final GlobalKey<NavigatorState> navKey;
  const _FilesTab({required this.navKey});

  @override
  State<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<_FilesTab> {
  ServerDto? _selectedServer;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 900;
    if (isTablet) {
      return _TabletSplitTab(
        leftPane: Column(
          children: [
            _TerminalTabHeader(
              title: 'Files',
              onAddServer: () => ServerFormDialog.show(context),
            ),
            Expanded(
              child: ServerListPage(
                onServerTap: (s) => setState(() => _selectedServer = s),
              ),
            ),
          ],
        ),
        rightPane: _selectedServer == null
            ? const _EmptyDetailPane(
                message: 'Select a server to browse files.',
              )
            : MobileSftpPage(
                key: ValueKey(_selectedServer!.id),
                server: _selectedServer!,
              ),
      );
    }
    return Navigator(
      key: widget.navKey,
      onGenerateRoute: (settings) {
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (_, __, ___) => const _FilesServerListScreen(),
        );
      },
    );
  }
}

/// AI tab content: hosts the shared `AiPanel` plus a corner affordance that
/// opens the mobile-only task history page (v0.79.24). The internal
/// Navigator keeps the history route inside the tab's back stack so the
/// system back gesture pops it without leaving the AI tab.
class _AiTab extends StatelessWidget {
  final GlobalKey<NavigatorState> navKey;
  final VoidCallback onConfigureAi;
  const _AiTab({required this.navKey, required this.onConfigureAi});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey,
      onGenerateRoute: (settings) => PageRouteBuilder(
        settings: settings,
        pageBuilder: (_, __, ___) => _AiTabRoot(onConfigureAi: onConfigureAi),
      ),
    );
  }
}

class _AiTabRoot extends StatelessWidget {
  final VoidCallback onConfigureAi;
  const _AiTabRoot({required this.onConfigureAi});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        Positioned.fill(child: AiPanel(onConfigureAi: onConfigureAi)),
        // Floating top-right affordance. Sits inside SafeArea so it doesn't
        // collide with the iPhone Dynamic Island / Android status bar.
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(PageRouteBuilder<void>(
                pageBuilder: (_, __, ___) => const MobileTaskHistoryPage(),
              )),
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: TermexColors.backgroundSecondary.withValues(alpha: 0.9),
                  border: Border.all(color: TermexColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      TermexIcons.history,
                      size: 14,
                      color: TermexColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.taskHistoryEntryAction,
                      style: TermexTypography.caption.copyWith(
                        color: TermexColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Three-pane tablet layout for Terminal / Files tabs.
///
/// 280pt fixed-width [leftPane] on the left, a 1-px divider, then
/// [rightPane] on the right.
///
/// v0.79.64 refactor: was hard-coded to "header + ServerListPage" left
/// pane + detail-or-empty right pane. iPad Terminal tab needed
/// sub-tabs (servers / proxies / snippets) to match iPhone parity,
/// which forced the left pane to vary by tab. Generic `leftPane` /
/// `rightPane` lets each caller compose its own structure: Terminal
/// builds a Column with header + sub-tabs + dispatched panel; Files
/// keeps the simple header + ServerListPage shape.
class _TabletSplitTab extends StatelessWidget {
  final Widget leftPane;
  final Widget rightPane;

  const _TabletSplitTab({
    required this.leftPane,
    required this.rightPane,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 280, child: leftPane),
        Container(width: 1, color: TermexColors.border),
        Expanded(child: rightPane),
      ],
    );
  }
}

class _EmptyDetailPane extends StatelessWidget {
  final String message;
  const _EmptyDetailPane({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TermexColors.backgroundPrimary,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TermexTypography.body.copyWith(
          color: TermexColors.textSecondary,
        ),
      ),
    );
  }
}

class _FilesServerListScreen extends StatelessWidget {
  const _FilesServerListScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TerminalTabHeader(
          title: 'Files',
          onAddServer: () => ServerFormDialog.show(context),
        ),
        Expanded(
          child: ServerListPage(
            onServerTap: (server) => _openSftp(context, server),
          ),
        ),
      ],
    );
  }

  void _openSftp(BuildContext context, ServerDto server) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => MobileSftpPage(server: server),
      ),
    );
  }
}

/// Mobile sub-tab categories for the Terminal tab. Mirrors the PC
/// sidebar's `SidebarCategory` (servers / proxies / snippets) so the
/// mobile shell exposes the same surfaces in a phone-friendly layout.
enum _MobileSidebarCategory { servers, proxies, snippets }

class _ServerListScreen extends ConsumerStatefulWidget {
  const _ServerListScreen();

  @override
  ConsumerState<_ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends ConsumerState<_ServerListScreen> {
  _MobileSidebarCategory _category = _MobileSidebarCategory.servers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // v0.79.59: dispatch the top-right "+" to the right "add" flow per
    // category — servers open `ServerFormDialog`, proxies open
    // `AddProxyDialog`, snippets enter the editor in "new" mode. Pre-
    // v0.79.59 only servers wired the +; proxies / snippets carried
    // their own inline "Add" affordance which duplicated the title and
    // pushed content down (esp. snippets' "+ 新建" beside the search
    // field). Now all three categories share the nav-bar "+" pattern.
    final onAdd = switch (_category) {
      _MobileSidebarCategory.servers => () => ServerFormDialog.show(context),
      _MobileSidebarCategory.proxies => () => AddProxyDialog.show(context),
      _MobileSidebarCategory.snippets => () => SnippetLibrary.startNew(ref),
    };
    return Column(
      children: [
        _TerminalTabHeader(
          title: switch (_category) {
            _MobileSidebarCategory.servers => l10n.sidebarServers,
            _MobileSidebarCategory.proxies => l10n.sidebarProxies,
            _MobileSidebarCategory.snippets => l10n.sidebarSnippets,
          },
          onAddServer: onAdd,
        ),
        _MobileSidebarTabs(
          active: _category,
          onSelect: (c) => setState(() => _category = c),
        ),
        Expanded(
          child: switch (_category) {
            _MobileSidebarCategory.servers => ServerListPage(
                onServerTap: (server) => _openTerminal(context, server),
              ),
            _MobileSidebarCategory.proxies => const ProxyPanel(),
            _MobileSidebarCategory.snippets => const SnippetLibrary(),
          },
        ),
      ],
    );
  }

  void _openTerminal(BuildContext context, ServerDto server) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => MobileTerminalPage(server: server),
      ),
    );
  }
}

class _MobileSidebarTabs extends StatelessWidget {
  final _MobileSidebarCategory active;
  final ValueChanged<_MobileSidebarCategory> onSelect;

  const _MobileSidebarTabs({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          _MobileSidebarTab(
            label: l10n.sidebarServers,
            icon: TermexIcons.terminal,
            active: active == _MobileSidebarCategory.servers,
            onTap: () => onSelect(_MobileSidebarCategory.servers),
          ),
          _MobileSidebarTab(
            label: l10n.sidebarProxies,
            icon: TermexIcons.proxy,
            active: active == _MobileSidebarCategory.proxies,
            onTap: () => onSelect(_MobileSidebarCategory.proxies),
          ),
          _MobileSidebarTab(
            label: l10n.sidebarSnippets,
            icon: TermexIcons.snippet,
            active: active == _MobileSidebarCategory.snippets,
            onTap: () => onSelect(_MobileSidebarCategory.snippets),
          ),
        ],
      ),
    );
  }
}

class _MobileSidebarTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _MobileSidebarTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        active ? TermexColors.primary : TermexColors.textSecondary;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active
                    ? TermexColors.primary
                    : const Color(0x00000000),
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TermexTypography.caption.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TerminalTabHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAddServer;
  const _TerminalTabHeader({
    required this.title,
    this.onAddServer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MobileTokens.navBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (onAddServer != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAddServer,
              child: Container(
                width: MobileTokens.minTouchTarget,
                height: MobileTokens.minTouchTarget,
                alignment: Alignment.center,
                child: const Icon(
                  TermexIcons.add,
                  size: 24,
                  color: TermexColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
