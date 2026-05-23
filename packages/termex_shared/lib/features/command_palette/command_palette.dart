/// Cmd+Shift+P command palette — fuzzy search across servers, tabs,
/// settings, and snippets. Mirrors VSCode's command palette behaviour.
library;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/colors.dart';
import '../../design/radius.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../server_list/state/connection_provider.dart';
import '../server_list/state/server_provider.dart';
import '../tabs/state/tab_controller.dart';

/// One actionable item in the palette.
class PaletteItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String category;
  final void Function(WidgetRef ref) onSelect;

  const PaletteItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
    required this.onSelect,
  });
}

/// Visibility provider — toggled by Cmd+Shift+P or programmatic calls.
final commandPaletteOpenProvider = StateProvider<bool>((ref) => false);

/// Aggregate command list combining servers, tabs, and built-in actions.
final commandPaletteItemsProvider = Provider<List<PaletteItem>>((ref) {
  final servers = ref.watch(serverListProvider).valueOrNull ?? [];
  final tabs = ref.watch(tabListProvider);
  final items = <PaletteItem>[];

  // Servers — connect / open SFTP
  for (final s in servers) {
    items.add(PaletteItem(
      id: 'server.connect.${s.id}',
      title: '连接 ${s.name}',
      subtitle: '${s.username}@${s.host}:${s.port}',
      icon: Icons.dns_outlined,
      category: 'Servers',
      onSelect: (r) {
        final tabNotifier = ref.read(tabListProvider.notifier);
        final tabId = tabNotifier.openTab(s.id, s.name);
        ref.read(connectionProvider(tabId).notifier).connect(s.id);
      },
    ));
  }

  // Open tabs — focus
  for (final t in tabs) {
    items.add(PaletteItem(
      id: 'tab.focus.${t.id}',
      title: t.title,
      subtitle: '切换到 Tab',
      icon: Icons.tab_outlined,
      category: 'Tabs',
      onSelect: (r) {
        ref.read(activeTabIdProvider.notifier).state = t.id;
      },
    ));
  }

  // System commands
  items.addAll(_systemCommands(ref));

  return items;
});

List<PaletteItem> _systemCommands(Ref ref) {
  return [
    PaletteItem(
      id: 'system.new_terminal',
      title: '新建终端',
      subtitle: 'New Terminal',
      icon: Icons.add_box_outlined,
      category: 'System',
      onSelect: (_) {},
    ),
    PaletteItem(
      id: 'system.open_settings',
      title: '打开设置',
      subtitle: 'Settings',
      icon: Icons.settings_outlined,
      category: 'System',
      onSelect: (_) {},
    ),
  ];
}

/// Fuzzy score (lower = better match). Returns null if no match.
int? fuzzyScore(String query, String text) {
  if (query.isEmpty) return 0;
  final q = query.toLowerCase();
  final t = text.toLowerCase();
  int score = 0;
  int qi = 0;
  int lastIdx = -1;
  for (int i = 0; i < t.length && qi < q.length; i++) {
    if (t[i] == q[qi]) {
      if (lastIdx >= 0) score += (i - lastIdx); // gap penalty
      lastIdx = i;
      qi++;
    }
  }
  if (qi < q.length) return null;
  return score + (t.length - q.length);
}

/// The overlay widget itself.
class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  int _highlight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<PaletteItem> _ranked() {
    final all = ref.read(commandPaletteItemsProvider);
    final q = _ctrl.text.trim();
    if (q.isEmpty) return all.take(50).toList();
    final scored = <(int, PaletteItem)>[];
    for (final item in all) {
      final s = fuzzyScore(q, '${item.title} ${item.subtitle} ${item.category}');
      if (s != null) scored.add((s, item));
    }
    scored.sort((a, b) => a.$1.compareTo(b.$1));
    return scored.take(50).map((e) => e.$2).toList();
  }

  void _close() {
    ref.read(commandPaletteOpenProvider.notifier).state = false;
  }

  void _selectAt(int idx, List<PaletteItem> items) {
    if (idx < 0 || idx >= items.length) return;
    final item = items[idx];
    _close();
    item.onSelect(ref);
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final items = _ranked();
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlight =
          items.isEmpty ? 0 : (_highlight + 1) % items.length);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _highlight =
          items.isEmpty ? 0 : (_highlight - 1 + items.length) % items.length);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _selectAt(_highlight, items);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final items = _ranked();
    if (_highlight >= items.length) _highlight = 0;

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            child: const ColoredBox(color: Color(0x80000000)),
          ),
        ),
        // Centered palette
        Center(
          child: Container(
            width: 560,
            margin: const EdgeInsets.only(top: 80),
            decoration: BoxDecoration(
              color: TermexColors.backgroundPrimary,
              borderRadius: TermexRadius.lg,
              border: Border.all(color: TermexColors.border),
            ),
            child: Focus(
              onKeyEvent: _handleKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.search,
                            size: 18, color: TermexColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: EditableText(
                            controller: _ctrl,
                            focusNode: _focus,
                            style: TermexTypography.body.copyWith(
                              color: TermexColors.textPrimary,
                            ),
                            cursorColor: TermexColors.primary,
                            backgroundCursorColor: TermexColors.textMuted,
                            onChanged: (_) => setState(() => _highlight = 0),
                          ),
                        ),
                        Text(
                          'Esc',
                          style: TermexTypography.caption.copyWith(
                            color: TermexColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: TermexColors.border,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: items.isEmpty
                        ? Padding(
                            padding:
                                const EdgeInsets.all(TermexSpacing.xl),
                            child: Text(
                              '无匹配项',
                              style: TermexTypography.body.copyWith(
                                color: TermexColors.textMuted,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (ctx, i) {
                              final item = items[i];
                              final isSel = i == _highlight;
                              return GestureDetector(
                                onTap: () => _selectAt(i, items),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) =>
                                      setState(() => _highlight = i),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                    color: isSel
                                        ? TermexColors.primary.withOpacity(0.12)
                                        : null,
                                    child: Row(
                                      children: [
                                        Icon(item.icon,
                                            size: 16,
                                            color: TermexColors.textSecondary),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.title,
                                                style: TermexTypography.body
                                                    .copyWith(
                                                  color: TermexColors
                                                      .textPrimary,
                                                ),
                                              ),
                                              Text(
                                                item.subtitle,
                                                style: TermexTypography
                                                    .caption
                                                    .copyWith(
                                                  color: TermexColors
                                                      .textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          item.category,
                                          style: TermexTypography.caption
                                              .copyWith(
                                            color: TermexColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
