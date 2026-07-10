/// Terminal settings tab — scrollback, tab width, mouse, bell, cursor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
import '../../../terminal/features/tmux/tmux_provider.dart';
import '../state/settings_provider.dart';
import '../widgets/setting_row.dart';

class TerminalTab extends ConsumerWidget {
  const TerminalTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).settings;
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SettingRow(
          label: '滚动缓冲行数',
          hint: '向上回滚历史的最大行数',
          child: DropdownButton<int>(
            // 5000 is the legacy default from the v0.x Tauri build — keep
            // it as a selectable option so users whose DB still has that
            // value don't see the DropdownButton assertion firing.
            // Defensive `_coerce` snaps any other unknown value to the
            // nearest supported option to keep the dropdown stable as
            // the option set evolves.
            value: _coerceScrollback(settings.scrollbackLines),
            dropdownColor: TermexColors.backgroundSecondary,
            items: const [
              DropdownMenuItem(value: 1000, child: Text('1,000 行')),
              DropdownMenuItem(value: 5000, child: Text('5,000 行')),
              DropdownMenuItem(value: 10000, child: Text('10,000 行')),
              DropdownMenuItem(value: 100000, child: Text('100,000 行')),
            ],
            onChanged: (v) =>
                notifier.update(settings.copyWith(scrollbackLines: v!)),
            style: const TextStyle(fontSize: 12, color: TermexColors.textPrimary),
          ),
        ),
        SettingRow(
          label: 'Tab 宽度',
          child: DropdownButton<int>(
            value: settings.tabWidth,
            dropdownColor: TermexColors.backgroundSecondary,
            items: const [
              DropdownMenuItem(value: 2, child: Text('2 空格')),
              DropdownMenuItem(value: 4, child: Text('4 空格')),
              DropdownMenuItem(value: 8, child: Text('8 空格')),
            ],
            onChanged: (v) => notifier.update(settings.copyWith(tabWidth: v!)),
            style: const TextStyle(fontSize: 12, color: TermexColors.textPrimary),
          ),
        ),
        SettingRow(
          label: '光标形状',
          child: DropdownButton<CursorShape>(
            value: settings.cursorShape,
            dropdownColor: TermexColors.backgroundSecondary,
            items: const [
              DropdownMenuItem(value: CursorShape.block, child: Text('方块')),
              DropdownMenuItem(value: CursorShape.underline, child: Text('下划线')),
              DropdownMenuItem(value: CursorShape.bar, child: Text('竖线')),
            ],
            onChanged: (v) =>
                notifier.update(settings.copyWith(cursorShape: v!)),
            style: const TextStyle(fontSize: 12, color: TermexColors.textPrimary),
          ),
        ),
        SettingRow(
          label: '光标闪烁',
          child: Switch(
            value: settings.cursorBlink,
            onChanged: (v) =>
                notifier.update(settings.copyWith(cursorBlink: v)),
          ),
        ),
        const _TmuxModeRow(),
      ],
    );
  }
}

/// Snaps an arbitrary stored value to the nearest supported scrollback
/// option. Without this, DropdownButton asserts when `value` doesn't
/// match exactly one DropdownMenuItem — easy to hit on legacy DBs.
int _coerceScrollback(int stored) {
  const options = [1000, 5000, 10000, 100000];
  if (options.contains(stored)) return stored;
  // Closest by absolute distance — gives a reasonable mapping for any
  // future migration without losing the user's intent.
  int best = options.first;
  int bestDist = (stored - best).abs();
  for (final o in options.skip(1)) {
    final d = (stored - o).abs();
    if (d < bestDist) {
      best = o;
      bestDist = d;
    }
  }
  return best;
}

class _TmuxModeRow extends ConsumerWidget {
  const _TmuxModeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(tmuxModeProvider).valueOrNull ?? TmuxMode.auto;
    return SettingRow(
      label: 'Tmux 多路复用',
      hint: '检测远端 tmux 会话并在状态栏显示',
      child: DropdownButton<TmuxMode>(
        value: mode,
        dropdownColor: TermexColors.backgroundSecondary,
        items: TmuxMode.values
            .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            ref.read(tmuxModeProvider.notifier).set(v);
          }
        },
        style: const TextStyle(fontSize: 12, color: TermexColors.textPrimary),
      ),
    );
  }
}
