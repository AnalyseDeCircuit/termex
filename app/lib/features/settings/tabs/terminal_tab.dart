/// Terminal settings tab — scrollback, tab width, mouse, bell, cursor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens.dart';
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
            value: settings.scrollbackLines,
            dropdownColor: TermexColors.backgroundSecondary,
            items: const [
              DropdownMenuItem(value: 1000, child: Text('1,000 行')),
              DropdownMenuItem(value: 10000, child: Text('10,000 行')),
              DropdownMenuItem(value: 100000, child: Text('100,000 行')),
            ],
            onChanged: (v) =>
                notifier.update(settings.copyWith(scrollbackLines: v!)),
            style: TextStyle(fontSize: 12, color: TermexColors.textPrimary),
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
            style: TextStyle(fontSize: 12, color: TermexColors.textPrimary),
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
            style: TextStyle(fontSize: 12, color: TermexColors.textPrimary),
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
      ],
    );
  }
}
