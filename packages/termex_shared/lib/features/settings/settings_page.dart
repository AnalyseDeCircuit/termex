/// Settings page — left sidebar navigation + content area.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/clickable.dart';
import '../notifications/notifications_tab.dart';
import 'tabs/about_tab.dart';
import 'tabs/ai_tab.dart';
import 'tabs/appearance_tab.dart';
import 'tabs/audit_tab.dart';
import 'tabs/backup_tab.dart';
import 'tabs/keybindings_tab.dart';
import 'tabs/local_ai_tab.dart';
import 'tabs/privacy_tab.dart';
import 'tabs/team_tab.dart';
import 'tabs/terminal_tab.dart';

enum SettingsTab {
  appearance,
  notifications,
  terminal,
  keybindings,
  ai,
  team,
  privacy,
  backup,
  audit,
  localAi,
  about,
}

/// Localized human label for a settings tab. Exposed as a top-level
/// helper so both the sidebar renderer and the search index can resolve
/// "外观 / 终端 / 隐私" etc. when the user types tab names into the
/// search box (previously the filter only looked at SettingEntry's
/// label+description, so tab-name queries silently miss).
String tabLabelFor(SettingsTab t, AppLocalizations l) => switch (t) {
      SettingsTab.appearance => l.settingsAppearance,
      SettingsTab.notifications => l.settingsNotifications,
      SettingsTab.terminal => l.settingsTerminal,
      SettingsTab.keybindings => l.settingsKeybindings,
      SettingsTab.ai => l.settingsAi,
      SettingsTab.team => l.settingsTeam,
      SettingsTab.privacy => l.settingsPrivacy,
      SettingsTab.backup => l.settingsBackup,
      SettingsTab.audit => l.settingsAudit,
      SettingsTab.localAi => l.settingsLocalAi,
      SettingsTab.about => l.settingsAbout,
    };

/// Caller-injected extra sidebar entry (v0.79.54). Lets the mobile shell
/// surface mobile-only settings (e.g. push-notification thresholds) as a
/// first-class sidebar item alongside the built-in tabs without having
/// to move that code into termex_shared (where it would drag the
/// mobile-only Riverpod providers + bridge dependencies in).
///
/// Insert position is anchored to a built-in [SettingsTab] via
/// [insertAfter] — the extra item renders directly below that tab in
/// the sidebar listing. Pass `null` to append at the end. [id] must be
/// unique among the extras passed in.
class SettingsExtraTab {
  final String id;
  final String Function(AppLocalizations l) labelBuilder;
  final IconData icon;
  final WidgetBuilder builder;
  final SettingsTab? insertAfter;

  const SettingsExtraTab({
    required this.id,
    required this.labelBuilder,
    required this.icon,
    required this.builder,
    this.insertAfter,
  });
}

class SettingsPage extends ConsumerStatefulWidget {
  /// When true, the page is rendered inside a dialog/sheet (e.g. the
  /// desktop settings modal which already paints its own title bar +
  /// close button). In that case the internal [_TitleBar] is suppressed
  /// to avoid the duplicate "设置" header users saw in v0.77.0 A/B
  /// screenshots. Standalone-route usage keeps the embedded title bar.
  final bool embedded;

  /// Optional list of extra sidebar entries injected by the caller —
  /// see [SettingsExtraTab]. Defaults to none.
  final List<SettingsExtraTab> extraTabs;

  /// Optional widget rendered above the thresholds in the built-in
  /// Notifications tab. v0.79.55: the mobile shell uses this to surface
  /// `MobileTaskNotifier`-backed test buttons (Send test notification /
  /// Fire demo task event) that can't live in shared because they
  /// depend on the mobile bus + plugin. Desktop leaves it null.
  final Widget? notificationsHeader;

  /// v0.79.56: deep-link entry — when set, the page opens with this tab
  /// already active. Used by [AiPanel]'s onboarding CTA to land the
  /// user directly on `SettingsTab.ai`. `null` = default to
  /// [SettingsTab.appearance] like before.
  final SettingsTab? initialTab;

  const SettingsPage({
    super.key,
    this.embedded = false,
    this.extraTabs = const [],
    this.notificationsHeader,
    this.initialTab,
  });

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  /// Active sidebar entry. Holds either a [SettingsTab] (built-in) or
  /// the [SettingsExtraTab.id] string of a caller-injected extra.
  late Object _active = widget.initialTab ?? SettingsTab.appearance;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.colors.backgroundPrimary,
      body: Column(
        children: [
          // Settings auto-save (see SettingsNotifier.update), so the title
          // bar carries no Save/Cancel pair. It used to appear the moment
          // any control changed, shifting the whole panel down and implying
          // the change was pending when it had in fact already applied.
          // In embedded mode the host dialog paints its own header, so the
          // bar collapses to nothing there.
          if (!widget.embedded) const _TitleBar(),
          Expanded(
            child: Row(
              children: [
                // Narrow viewports (iPhone, narrow Android) get a compact
                // 96px sidebar (vs desktop's 176px) so the detail pane
                // dominates the screen. `_SidebarItem` reduces its own
                // padding/icon size for the mobile width so 4-char Chinese
                // labels ("审计日志", "AI 助手") still fit. The shared
                // 600px breakpoint matches mobile_tokens.dart and the
                // AiPanel single-pane decision in v0.78.1.
                SizedBox(
                  // v0.77.0: tightened from 176→140 for desktop. Sidebar
                  // labels max out at 4 Chinese chars ("审计日志" / "AI
                  // 助手"), which fit in ~90px content + 14px icon + 24px
                  // padding ≈ 130px. 140 gives breathing room without
                  // wasting horizontal space the detail pane can use.
                  width: MediaQuery.sizeOf(context).width < 600 ? 96 : 140,
                  child: Container(
                    color: context.colors.backgroundSecondary,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: _buildSidebarItems(l10n),
                    ),
                  ),
                ),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the sidebar list, interleaving caller-injected
  /// [SettingsExtraTab]s directly under their declared [insertAfter]
  /// builtin tab. Extras with `insertAfter == null` append at the end.
  List<Widget> _buildSidebarItems(AppLocalizations l10n) {
    final items = <Widget>[];
    for (final t in SettingsTab.values) {
      items.add(_SidebarItem(
        tab: t,
        isActive: _active == t,
        onTap: () => setState(() => _active = t),
      ));
      for (final extra in widget.extraTabs.where((e) => e.insertAfter == t)) {
        items.add(_ExtraSidebarItem(
          extra: extra,
          label: extra.labelBuilder(l10n),
          isActive: _active == extra.id,
          onTap: () => setState(() => _active = extra.id),
        ));
      }
    }
    for (final extra in widget.extraTabs.where((e) => e.insertAfter == null)) {
      items.add(_ExtraSidebarItem(
        extra: extra,
        label: extra.labelBuilder(l10n),
        isActive: _active == extra.id,
        onTap: () => setState(() => _active = extra.id),
      ));
    }
    return items;
  }

  Widget _buildContent() {
    final active = _active;
    if (active is SettingsTab) {
      return switch (active) {
        SettingsTab.appearance => const AppearanceTab(),
        SettingsTab.notifications =>
          NotificationsTab(header: widget.notificationsHeader),
        SettingsTab.terminal => const TerminalTab(),
        SettingsTab.keybindings => const KeybindingsTab(),
        SettingsTab.ai => const AiTab(),
        SettingsTab.team => const TeamTab(),
        SettingsTab.privacy => const PrivacyTab(),
        SettingsTab.backup => const BackupTab(),
        SettingsTab.audit => const AuditTab(),
        SettingsTab.localAi => const LocalAiTab(),
        SettingsTab.about => const AboutTab(),
      };
    }
    final extra = widget.extraTabs.firstWhere(
      (e) => e.id == active,
      orElse: () => widget.extraTabs.first,
    );
    return Builder(builder: extra.builder);
  }
}

/// Standalone-route header. Settings auto-save, so this is a plain title
/// strip with no Save/Cancel actions. The embedded (dialog) presentation
/// skips it entirely — the host dialog paints its own header.
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      // 32, not 44: the bar carries a single label and no controls, so the
      // extra height only pushed the panel's actual content down.
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.colors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          Text(
            l10n.settingsTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final SettingsTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Narrow viewports get tighter padding + smaller icon spacing so
    // 4-char Chinese labels ("审计日志", "AI 助手") fit in the 96px
    // sidebar without truncation.
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final horizontalPad = isMobile ? 6.0 : 12.0;
    final iconSize = isMobile ? 13.0 : 14.0;
    final iconGap = isMobile ? 4.0 : 8.0;
    return Clickable(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: EdgeInsets.symmetric(horizontal: horizontalPad),
        decoration: BoxDecoration(
          color: isActive ? context.colors.primary.withValues(alpha: 0.1) : null,
          border: Border(
            left: BorderSide(
              color: isActive ? context.colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(_tabIcon(tab),
                size: iconSize,
                color: isActive
                    ? context.colors.primary
                    : context.colors.textSecondary),
            SizedBox(width: iconGap),
            Expanded(
              child: Text(
                tabLabelFor(tab, AppLocalizations.of(context)),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive
                      ? context.colors.textPrimary
                      : context.colors.textSecondary,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _tabIcon(SettingsTab t) => switch (t) {
        SettingsTab.appearance => Icons.palette_outlined,
        SettingsTab.notifications => Icons.notifications_outlined,
        SettingsTab.terminal => Icons.terminal,
        SettingsTab.keybindings => Icons.keyboard_outlined,
        SettingsTab.ai => Icons.smart_toy_outlined,
        SettingsTab.team => Icons.group_outlined,
        SettingsTab.privacy => Icons.security_outlined,
        SettingsTab.backup => Icons.backup_outlined,
        SettingsTab.audit => Icons.history,
        SettingsTab.localAi => Icons.psychology_outlined,
        SettingsTab.about => Icons.info_outline,
      };
}

/// Sidebar entry for a caller-injected [SettingsExtraTab]. Matches
/// [_SidebarItem]'s visuals (active border / icon + label / mobile-narrow
/// padding) so injected extras read as siblings of the built-ins rather
/// than as a separate styled list.
class _ExtraSidebarItem extends StatelessWidget {
  final SettingsExtraTab extra;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ExtraSidebarItem({
    required this.extra,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final horizontalPad = isMobile ? 6.0 : 12.0;
    final iconSize = isMobile ? 13.0 : 14.0;
    final iconGap = isMobile ? 4.0 : 8.0;
    return Clickable(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: EdgeInsets.symmetric(horizontal: horizontalPad),
        decoration: BoxDecoration(
          color: isActive ? context.colors.primary.withValues(alpha: 0.1) : null,
          border: Border(
            left: BorderSide(
              color: isActive ? context.colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(extra.icon,
                size: iconSize,
                color: isActive
                    ? context.colors.primary
                    : context.colors.textSecondary),
            SizedBox(width: iconGap),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive
                      ? context.colors.textPrimary
                      : context.colors.textSecondary,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
