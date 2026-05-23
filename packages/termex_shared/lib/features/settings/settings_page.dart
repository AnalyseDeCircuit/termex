/// Settings page — left sidebar navigation + content area.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'state/settings_provider.dart';
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

/// A setting-search entry used to jump directly to a specific tab when the
/// user types in the search box.  Spec §4.1.5.
class SettingEntry {
  final String id;
  final String label;
  final String description;
  final SettingsTab tab;

  const SettingEntry({
    required this.id,
    required this.label,
    required this.description,
    required this.tab,
  });
}

/// Returns the localized search index.  Lazily built from the current
/// [AppLocalizations]; called only when the user types into the search box,
/// so the i18n cost is paid only when needed.
List<SettingEntry> buildSettingsIndex(AppLocalizations l) => [
      SettingEntry(id: 'theme', label: l.settingsIdxThemeLabel, description: l.settingsIdxThemeDesc, tab: SettingsTab.appearance),
      SettingEntry(id: 'font', label: l.settingsIdxFontLabel, description: l.settingsIdxFontDesc, tab: SettingsTab.appearance),
      SettingEntry(id: 'cursor', label: l.settingsIdxCursorLabel, description: l.settingsIdxCursorDesc, tab: SettingsTab.terminal),
      SettingEntry(id: 'scrollback', label: l.settingsIdxScrollbackLabel, description: l.settingsIdxScrollbackDesc, tab: SettingsTab.terminal),
      SettingEntry(id: 'tab_width', label: l.settingsIdxTabWidthLabel, description: l.settingsIdxTabWidthDesc, tab: SettingsTab.terminal),
      SettingEntry(id: 'keybindings', label: l.settingsIdxKeybindingsLabel, description: l.settingsIdxKeybindingsDesc, tab: SettingsTab.keybindings),
      SettingEntry(id: 'ai_provider', label: l.settingsIdxAiProviderLabel, description: l.settingsIdxAiProviderDesc, tab: SettingsTab.ai),
      SettingEntry(id: 'ai_context', label: l.settingsIdxAiContextLabel, description: l.settingsIdxAiContextDesc, tab: SettingsTab.ai),
      SettingEntry(id: 'team_passphrase', label: l.settingsIdxTeamPassphraseLabel, description: l.settingsIdxTeamPassphraseDesc, tab: SettingsTab.team),
      SettingEntry(id: 'privacy_clear', label: l.settingsIdxPrivacyClearLabel, description: l.settingsIdxPrivacyClearDesc, tab: SettingsTab.privacy),
      SettingEntry(id: 'gdpr_erase', label: l.settingsIdxGdprEraseLabel, description: l.settingsIdxGdprEraseDesc, tab: SettingsTab.privacy),
      SettingEntry(id: 'backup', label: l.settingsIdxBackupLabel, description: l.settingsIdxBackupDesc, tab: SettingsTab.backup),
      SettingEntry(id: 'audit', label: l.settingsIdxAuditLabel, description: l.settingsIdxAuditDesc, tab: SettingsTab.audit),
      SettingEntry(id: 'local_ai', label: l.settingsIdxLocalAiLabel, description: l.settingsIdxLocalAiDesc, tab: SettingsTab.localAi),
      SettingEntry(id: 'about', label: l.settingsIdxAboutLabel, description: l.settingsIdxAboutDesc, tab: SettingsTab.about),
    ];

class SettingsPage extends ConsumerStatefulWidget {
  /// When true, the page is rendered inside a dialog/sheet rather than as
  /// a standalone route — currently only affects future styling tweaks; the
  /// flag is accepted so DesktopShell can pass it without an extra branch.
  final bool embedded;

  const SettingsPage({super.key, this.embedded = false});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  SettingsTab _active = SettingsTab.appearance;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Filters the settings index by label+description against the current
  /// search query.  Exposed so widget tests can verify search behaviour.
  List<SettingEntry> filteredIndex(AppLocalizations l) {
    if (_searchQuery.isEmpty) return const [];
    final q = _searchQuery.toLowerCase();
    return buildSettingsIndex(l)
        .where((e) =>
            e.label.toLowerCase().contains(q) ||
            e.description.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDirty = ref.watch(settingsProvider).isDirty;
    final matches = filteredIndex(l10n);

    return Scaffold(
      backgroundColor: TermexColors.backgroundPrimary,
      body: Column(
        children: [
          _TitleBar(
            isDirty: isDirty,
            onSave: () => ref.read(settingsProvider.notifier).save(),
            onReset: () =>
                ref.read(settingsProvider.notifier).resetToDefaults(),
          ),
          _SearchBar(
            controller: _searchCtrl,
            onChanged: (q) => setState(() => _searchQuery = q),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 176,
                  child: Container(
                    color: TermexColors.backgroundSecondary,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: SettingsTab.values
                          .map((t) => _SidebarItem(
                                tab: t,
                                isActive: t == _active,
                                onTap: () => setState(() => _active = t),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: _searchQuery.isNotEmpty
                      ? _SearchResults(
                          matches: matches,
                          onTap: (tab) =>
                              setState(() => _active = tab),
                        )
                      : _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return switch (_active) {
      SettingsTab.appearance => const AppearanceTab(),
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
}

class _TitleBar extends StatelessWidget {
  final bool isDirty;
  final VoidCallback onSave;
  final VoidCallback onReset;

  const _TitleBar({
    required this.isDirty,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          Text(
            l10n.settingsTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: TermexColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (isDirty) ...[
            TextButton(
              onPressed: onReset,
              child: Text(l10n.commonCancel,
                  style: const TextStyle(
                      fontSize: 12, color: TermexColors.textSecondary)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: TermexColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(64, 30),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text(l10n.commonSave),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: l10n.settingsSearchPlaceholder,
          hintStyle:
              const TextStyle(fontSize: 12, color: TermexColors.textSecondary),
          prefixIcon:
              const Icon(Icons.search, size: 16, color: TermexColors.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: TermexColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: TermexColors.border),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 12, color: TermexColors.textPrimary),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<SettingEntry> matches;
  final void Function(SettingsTab) onTap;

  const _SearchResults({required this.matches, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).settingsSearchNoMatch,
          style: const TextStyle(
              fontSize: 13, color: TermexColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const Divider(color: TermexColors.border, height: 1),
      itemBuilder: (ctx, i) {
        final e = matches[i];
        return ListTile(
          dense: true,
          title: Text(e.label,
              style: const TextStyle(fontSize: 13, color: TermexColors.textPrimary)),
          subtitle: Text(e.description,
              style: const TextStyle(fontSize: 11, color: TermexColors.textSecondary)),
          onTap: () => onTap(e.tab),
        );
      },
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? TermexColors.primary.withOpacity(0.1) : null,
          border: Border(
            left: BorderSide(
              color: isActive ? TermexColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(_tabIcon(tab),
                size: 14,
                color: isActive
                    ? TermexColors.primary
                    : TermexColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              _tabLabel(tab, AppLocalizations.of(context)),
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? TermexColors.textPrimary
                    : TermexColors.textSecondary,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _tabIcon(SettingsTab t) => switch (t) {
        SettingsTab.appearance => Icons.palette_outlined,
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

  String _tabLabel(SettingsTab t, AppLocalizations l) => switch (t) {
        SettingsTab.appearance => l.settingsAppearance,
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
}
