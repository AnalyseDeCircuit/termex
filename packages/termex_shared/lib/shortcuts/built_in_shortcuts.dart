/// Built-in shortcut definitions (v0.48 spec §4.3).
///
/// On macOS, modifier is `cmd`; on other platforms, `ctrl`.
/// The registry is populated once at app startup from these defaults.
library;

import 'dart:io';

import 'shortcut_registry.dart';
import 'shortcut_scope.dart';

String get _mod => Platform.isMacOS ? 'cmd' : 'ctrl';

/// Returns the canonical built-in shortcut list.
///
/// Keys follow the format `"mod+key"` (all lower-case).  Platform modifier is
/// resolved at call time so tests can override via `Platform` if needed.
List<ShortcutBinding> builtInShortcuts() {
  final m = _mod;
  return [
    // ── Workspace ──────────────────────────────────────────────────────────
    _b('tab.new', '$m+t', ShortcutScope.global, '新建 Tab'),
    _b('tab.close', '$m+w', ShortcutScope.tab, '关闭 Tab'),
    _b('tab.nextTab', '$m+]', ShortcutScope.global, '下一个 Tab'),
    _b('tab.prevTab', '$m+[', ShortcutScope.global, '上一个 Tab'),
    _b('pane.splitH', '$m+d', ShortcutScope.tab, '水平分割'),
    _b('pane.splitV', '$m+shift+d', ShortcutScope.tab, '垂直分割'),

    // ── Terminal ───────────────────────────────────────────────────────────
    _b('terminal.search', '$m+f', ShortcutScope.terminal, '终端内搜索'),
    _b('terminal.clear', '$m+k', ShortcutScope.terminal, '清屏'),
    _b('terminal.copy', '$m+c', ShortcutScope.terminal, '复制选中'),
    _b('terminal.paste', '$m+v', ShortcutScope.terminal, '粘贴'),

    // ── SFTP ───────────────────────────────────────────────────────────────
    _b('sftp.open', '$m+shift+f', ShortcutScope.tab, '打开 SFTP'),

    // ── AI ─────────────────────────────────────────────────────────────────
    _b('ai.ask', '$m+j', ShortcutScope.global, 'AI 问答'),
    _b('ai.nl2cmd', 'shift+space', ShortcutScope.terminal, 'NL → 命令'),

    // ── Sidebar / Search ───────────────────────────────────────────────────
    _b('sidebar.toggle', '$m+b', ShortcutScope.global, '切换侧边栏'),
    _b('sidebar.search', '$m+k', ShortcutScope.global, '全局搜索'),

    // ── View ───────────────────────────────────────────────────────────────
    _b('monitor.toggle', '$m+shift+m', ShortcutScope.tab, '切换监控'),
    _b('crossTab.search', '$m+shift+f', ShortcutScope.global, '跨 Tab 搜索'),

    // ── App ────────────────────────────────────────────────────────────────
    _b('settings.open', '$m+,', ShortcutScope.global, '打开设置'),
    _b('app.lock', '$m+l', ShortcutScope.global, '锁定'),
    _b('app.quit', '$m+q', ShortcutScope.global, '退出'),
  ];
}

/// Registers all built-in shortcuts into [registry].
///
/// Existing entries are NOT overwritten so that user overrides loaded before
/// this call take precedence.
void registerBuiltInShortcuts(ShortcutRegistry registry) {
  for (final b in builtInShortcuts()) {
    if (registry.all.every((e) => e.commandId != b.commandId)) {
      registry.register(b);
    }
  }
}

ShortcutBinding _b(
    String id, String combo, ShortcutScope scope, String description) {
  return ShortcutBinding(
    commandId: id,
    combo: KeyCombination(combo),
    scope: scope,
    description: description,
  );
}
