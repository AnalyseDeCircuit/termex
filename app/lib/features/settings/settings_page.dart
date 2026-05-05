/// Settings page — left sidebar navigation + content area.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
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

/// The canonical index used by the search bar.  Kept in-line so the Dart
/// code is self-documenting.
const List<SettingEntry> kSettingsIndex = [
  SettingEntry(id: 'theme', label: '主题', description: '浅色 / 深色 / 跟随系统', tab: SettingsTab.appearance),
  SettingEntry(id: 'font', label: '字体', description: '终端字体与字号', tab: SettingsTab.appearance),
  SettingEntry(id: 'cursor', label: '光标', description: '光标形状与闪烁', tab: SettingsTab.terminal),
  SettingEntry(id: 'scrollback', label: '滚动缓冲', description: '终端历史行数', tab: SettingsTab.terminal),
  SettingEntry(id: 'tab_width', label: 'Tab 宽度', description: '2 / 4 / 8 空格', tab: SettingsTab.terminal),
  SettingEntry(id: 'keybindings', label: '快捷键', description: '自定义命令与冲突检测', tab: SettingsTab.keybindings),
  SettingEntry(id: 'ai_provider', label: 'AI Provider', description: 'Claude / OpenAI / Ollama / Local', tab: SettingsTab.ai),
  SettingEntry(id: 'ai_context', label: 'AI 上下文', description: '发送给 AI 的终端行数', tab: SettingsTab.ai),
  SettingEntry(id: 'team_passphrase', label: '团队加密密码', description: '团队同步解锁', tab: SettingsTab.team),
  SettingEntry(id: 'privacy_clear', label: '隐私数据清除', description: '连接历史 / AI 对话 / Snippet 统计', tab: SettingsTab.privacy),
  SettingEntry(id: 'gdpr_erase', label: 'GDPR 数据擦除', description: '永久删除所有本地数据', tab: SettingsTab.privacy),
  SettingEntry(id: 'backup', label: '备份导出/导入', description: '.termex 加密文件', tab: SettingsTab.backup),
  SettingEntry(id: 'audit', label: '审计日志', description: '事件查询 / CSV 导出', tab: SettingsTab.audit),
  SettingEntry(id: 'local_ai', label: '本地 AI', description: 'llama-server 端口与模型', tab: SettingsTab.localAi),
  SettingEntry(id: 'about', label: '关于', description: '版本与许可证', tab: SettingsTab.about),
];

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

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
  List<SettingEntry> filteredIndex() {
    if (_searchQuery.isEmpty) return const [];
    final q = _searchQuery.toLowerCase();
    return kSettingsIndex
        .where((e) =>
            e.label.toLowerCase().contains(q) ||
            e.description.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDirty = ref.watch(settingsProvider).isDirty;
    final matches = filteredIndex();

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
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: Row(
        children: [
          Text(
            '设置',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: TermexColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (isDirty) ...[
            TextButton(
              onPressed: onReset,
              child: Text('取消',
                  style: TextStyle(
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
              child: const Text('保存'),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: TermexColors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: TermexColors.border)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: '搜索设置…',
          hintStyle:
              TextStyle(fontSize: 12, color: TermexColors.textSecondary),
          prefixIcon:
              Icon(Icons.search, size: 16, color: TermexColors.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: TermexColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: TermexColors.border),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          isDense: true,
        ),
        style: TextStyle(fontSize: 12, color: TermexColors.textPrimary),
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
          '无匹配的设置项',
          style: TextStyle(fontSize: 13, color: TermexColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      separatorBuilder: (_, __) => Divider(color: TermexColors.border, height: 1),
      itemBuilder: (ctx, i) {
        final e = matches[i];
        return ListTile(
          dense: true,
          title: Text(e.label,
              style: TextStyle(fontSize: 13, color: TermexColors.textPrimary)),
          subtitle: Text(e.description,
              style: TextStyle(fontSize: 11, color: TermexColors.textSecondary)),
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
              _tabLabel(tab),
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

  String _tabLabel(SettingsTab t) => switch (t) {
        SettingsTab.appearance => '外观',
        SettingsTab.terminal => '终端',
        SettingsTab.keybindings => '快捷键',
        SettingsTab.ai => 'AI 助手',
        SettingsTab.team => '团队',
        SettingsTab.privacy => '隐私',
        SettingsTab.backup => '备份',
        SettingsTab.audit => '审计日志',
        SettingsTab.localAi => '本地 AI',
        SettingsTab.about => '关于',
      };
}
